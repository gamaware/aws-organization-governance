# KMS key for encryption
resource "aws_kms_key" "cleanup" {
  description             = "Encryption key for cleanup reports and notifications"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "cleanup" {
  name          = "alias/cleanup"
  target_key_id = aws_kms_key.cleanup.key_id
}

# S3 bucket for cleanup reports and AI analysis
resource "aws_s3_bucket" "cleanup_reports" {
  bucket = "cleanup-reports-${var.account_id}"
}

resource "aws_s3_bucket_versioning" "cleanup_reports" {
  bucket = aws_s3_bucket.cleanup_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cleanup_reports" {
  bucket = aws_s3_bucket.cleanup_reports.id

  rule {
    id     = "expire-old-reports"
    status = "Enabled"
    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cleanup_reports" {
  bucket = aws_s3_bucket.cleanup_reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cleanup.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cleanup_reports" {
  bucket                  = aws_s3_bucket.cleanup_reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SNS topic for cleanup notifications
resource "aws_sns_topic" "cleanup_notifications" {
  name              = "cleanup-notifications"
  kms_master_key_id = aws_kms_key.cleanup.id
}

resource "aws_sns_topic_subscription" "cleanup_email" {
  topic_arn = aws_sns_topic.cleanup_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# aws-nuke config rendered from template
resource "aws_s3_object" "nuke_config" {
  bucket = aws_s3_bucket.cleanup_reports.id
  key    = "config/nuke-config.yaml"
  content = templatefile("${path.module}/nuke-config.yaml.tpl", {
    account_id = var.account_id
    team_tags  = var.team_tags
  })
}

# Lambda function for AI verification
data "archive_file" "ai_verify_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "ai_verify" {
  function_name    = "cleanup-ai-verify"
  filename         = data.archive_file.ai_verify_lambda.output_path
  source_code_hash = data.archive_file.ai_verify_lambda.output_base64sha256
  handler          = "ai_verify.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 512
  role             = aws_iam_role.lambda_execution.arn
  kms_key_arn      = aws_kms_key.cleanup.arn

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      REPORTS_BUCKET    = aws_s3_bucket.cleanup_reports.id
      ACCOUNT_ID        = var.account_id
      TEAM_TAGS         = jsonencode(var.team_tags)
      SNS_TOPIC_ARN     = aws_sns_topic.cleanup_notifications.arn
      ACCEPTED_FINDINGS = filebase64("${path.module}/accepted-findings.md")
    }
  }
}

# CodeBuild project for aws-nuke
resource "aws_codebuild_project" "cleanup" {
  name          = "resource-cleanup"
  description   = "Runs aws-nuke to delete tagged student resources"
  service_role  = aws_iam_role.codebuild_execution.arn
  build_timeout = 480

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "NUKE_CONFIG_BUCKET"
      value = aws_s3_bucket.cleanup_reports.id
    }

    environment_variable {
      name  = "NUKE_CONFIG_KEY"
      value = "config/nuke-config.yaml"
    }

    environment_variable {
      name  = "REPORTS_BUCKET"
      value = aws_s3_bucket.cleanup_reports.id
    }

    environment_variable {
      name  = "ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "NUKE_VERSION"
      value = var.nuke_version
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          commands:
            - echo "Installing aws-nuke $NUKE_VERSION..."
            - curl -sSfL "https://github.com/ekristen/aws-nuke/releases/download/$NUKE_VERSION/aws-nuke-$NUKE_VERSION-linux-amd64.tar.gz" | tar xzf - -C /usr/local/bin
            - chmod +x /usr/local/bin/aws-nuke
        pre_build:
          commands:
            - echo "Downloading nuke config..."
            - aws s3 cp "s3://$NUKE_CONFIG_BUCKET/$NUKE_CONFIG_KEY" /tmp/nuke-config.yaml
            - export TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
            - export DRY_RUN_FLAG=$${DRY_RUN:+"--dry-run"}
        build:
          commands:
            - echo "Running aws-nuke $${DRY_RUN:+(dry-run)}..."
            - |
              aws-nuke run \
                --config /tmp/nuke-config.yaml \
                --no-prompt \
                --force \
                $DRY_RUN_FLAG \
                2>&1 | tee /tmp/nuke-output.log || true
        post_build:
          commands:
            - echo "Uploading report..."
            - aws s3 cp /tmp/nuke-output.log "s3://$REPORTS_BUCKET/reports/$TIMESTAMP/nuke-output.log"
            - echo "Done."
    BUILDSPEC
  }
}

# Step Functions state machine
resource "aws_sfn_state_machine" "cleanup" {
  name     = "resource-cleanup"
  role_arn = aws_iam_role.step_functions_execution.arn

  definition = jsonencode({
    Comment = "Orchestrates Dev account resource cleanup"
    StartAt = "Discovery"
    States = {
      Discovery = {
        Type     = "Task"
        Resource = "arn:aws:states:::codebuild:startBuild.sync"
        Parameters = {
          ProjectName = aws_codebuild_project.cleanup.name
          EnvironmentVariablesOverride = [
            {
              Name  = "DRY_RUN"
              Value = "true"
              Type  = "PLAINTEXT"
            }
          ]
        }
        ResultPath = "$.discovery"
        Next       = "NotifyDiscovery"
      }
      NotifyDiscovery = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.cleanup_notifications.arn
          Subject  = "Cleanup Discovery Complete — Review Required"
          Message  = "Dry-run report generated. Review in S3 before approving deletion. Approve via AWS Console (send-task-success) or reject (send-task-failure)."
        }
        ResultPath = "$.notify_discovery"
        Next       = "WaitForApproval"
      }
      WaitForApproval = {
        Type           = "Task"
        Resource       = "arn:aws:states:::activity:waitForTaskToken"
        TimeoutSeconds = 86400
        Parameters = {
          "taskToken.$" = "$$.Task.Token"
        }
        ResultPath = "$.approval"
        Next       = "Cleanup"
        Catch = [
          {
            ErrorEquals = ["States.Timeout"]
            Next        = "ApprovalTimeout"
          }
        ]
      }
      ApprovalTimeout = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.cleanup_notifications.arn
          Subject  = "Cleanup Approval Timeout"
          Message  = "No approval received within 24 hours. Cleanup aborted."
        }
        End = true
      }
      Cleanup = {
        Type     = "Task"
        Resource = "arn:aws:states:::codebuild:startBuild.sync"
        Parameters = {
          ProjectName = aws_codebuild_project.cleanup.name
          EnvironmentVariablesOverride = [
            {
              Name  = "DRY_RUN"
              Value = ""
              Type  = "PLAINTEXT"
            }
          ]
        }
        ResultPath = "$.cleanup"
        Next       = "AIVerify"
      }
      AIVerify = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.ai_verify.arn
          Payload = {
            "execution_id.$" = "$$.Execution.Id"
          }
        }
        ResultPath = "$.ai_verify"
        Next       = "NotifyComplete"
      }
      NotifyComplete = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.cleanup_notifications.arn
          Subject     = "Cleanup Complete"
          "Message.$" = "States.Format('Cleanup finished. AI verdict: {}. Reports in S3.', $.ai_verify.Payload.verdict)"
        }
        End = true
      }
    }
  })
}

# Step Functions Activity for approval callback
resource "aws_sfn_activity" "cleanup_approval" {
  name = "cleanup-approval"
}

# EventBridge Scheduler
resource "aws_scheduler_schedule" "cleanup" {
  name       = "resource-cleanup-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.cleanup_schedule
  schedule_expression_timezone = "America/Chicago"

  target {
    arn      = aws_sfn_state_machine.cleanup.arn
    role_arn = aws_iam_role.scheduler_execution.arn
    input    = jsonencode({ dry_run = false })
  }
}
