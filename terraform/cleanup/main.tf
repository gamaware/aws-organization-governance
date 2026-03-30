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
  bucket        = "dev-cleanup-reports-${var.account_id}"
  force_destroy = true
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
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
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
      name  = "REPORTS_BUCKET"
      value = aws_s3_bucket.cleanup_reports.id
    }

    environment_variable {
      name  = "ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "TEAM_TAGS"
      value = jsonencode(var.team_tags)
    }
  }

  encryption_key = aws_kms_key.cleanup.arn

  source {
    type      = "NO_SOURCE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      env:
        shell: bash
      phases:
        pre_build:
          commands:
            - export TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
            - echo "=== Tag-Based Resource Cleanup ==="
            - echo "Account $ACCOUNT_ID | DRY_RUN=$DRY_RUN"
            - echo "Team tags $TEAM_TAGS"
        build:
          commands:
            - |
              # Find all resources with Team tags
              TEAMS=$(echo "$TEAM_TAGS" | tr -d '[]"' | tr ',' ' ')
              echo "Scanning for tagged resources..."
              > /tmp/nuke-output.log
              > /tmp/all-arns.txt

              # Phase 0: Collect ALL tagged resources
              for TEAM in $TEAMS; do
                echo "--- Scanning Team=$TEAM ---" | tee -a /tmp/nuke-output.log
                aws resourcegroupstaggingapi get-resources \
                  --tag-filters Key=Team,Values=$TEAM \
                  --query 'ResourceTagMappingList[].ResourceARN' \
                  --output text 2>/dev/null | tr '\t' '\n' >> /tmp/all-arns.txt
              done

              TOTAL_FOUND=$(wc -l < /tmp/all-arns.txt | tr -d ' ')
              echo "Found $TOTAL_FOUND tagged resources" | tee -a /tmp/nuke-output.log

              if [ "$TOTAL_FOUND" = "0" ]; then
                echo "Nothing to clean" | tee -a /tmp/nuke-output.log
              elif [ -n "$DRY_RUN" ]; then
                # Dry-run: just list
                while read ARN; do
                  [ -n "$ARN" ] && echo "  [DRY-RUN] would remove: $ARN" | tee -a /tmp/nuke-output.log
                done < /tmp/all-arns.txt
              else
                # Phase 1: Terminate EC2 instances first
                echo "=== Phase 1: Terminating EC2 instances ===" | tee -a /tmp/nuke-output.log
                INSTANCE_IDS=""
                while read ARN; do
                  if echo "$ARN" | grep -q ":instance/"; then
                    ID=$(echo "$ARN" | rev | cut -d/ -f1 | rev)
                    INSTANCE_IDS="$INSTANCE_IDS $ID"
                    echo "  [DELETE] terminating: $ARN" | tee -a /tmp/nuke-output.log
                  fi
                done < /tmp/all-arns.txt

                if [ -n "$INSTANCE_IDS" ]; then
                  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS 2>&1 | tee -a /tmp/nuke-output.log
                  echo "Waiting for instance termination..." | tee -a /tmp/nuke-output.log
                  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS 2>/dev/null || sleep 60
                  echo "Instances terminated" | tee -a /tmp/nuke-output.log
                fi

                # Phase 2: Delete everything else
                echo "=== Phase 2: Deleting remaining resources ===" | tee -a /tmp/nuke-output.log
                while read ARN; do
                  [ -z "$ARN" ] && continue
                  # Skip instances (already handled)
                  echo "$ARN" | grep -q ":instance/" && continue

                  TYPE=$(echo "$ARN" | cut -d: -f3)
                  RESOURCE_ID=$(echo "$ARN" | rev | cut -d/ -f1 | rev)
                  echo "  [DELETE] removing: $ARN" | tee -a /tmp/nuke-output.log
                    case "$TYPE" in
                      ec2)
                        RTYPE=$(echo "$ARN" | cut -d: -f6 | cut -d/ -f1)
                        case "$RTYPE" in
                          instance) aws ec2 terminate-instances --instance-ids "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          volume) aws ec2 delete-volume --volume-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          security-group) aws ec2 delete-security-group --group-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          vpc) aws ec2 delete-vpc --vpc-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          subnet) aws ec2 delete-subnet --subnet-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          internet-gateway) aws ec2 delete-internet-gateway --internet-gateway-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          natgateway) aws ec2 delete-nat-gateway --nat-gateway-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          route-table) aws ec2 delete-route-table --route-table-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          elastic-ip) aws ec2 release-address --allocation-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          snapshot) aws ec2 delete-snapshot --snapshot-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          key-pair) aws ec2 delete-key-pair --key-pair-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          *) echo "    [SKIP] unknown ec2 type: $RTYPE" | tee -a /tmp/nuke-output.log ;;
                        esac ;;
                      rds)
                        aws rds delete-db-instance --db-instance-identifier "$RESOURCE_ID" --skip-final-snapshot 2>&1 | tee -a /tmp/nuke-output.log ;;
                      lambda)
                        aws lambda delete-function --function-name "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      dynamodb)
                        aws dynamodb delete-table --table-name "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      sqs)
                        QUEUE_NAME=$(echo "$ARN" | rev | cut -d: -f1 | rev)
                        QUEUE_URL=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --query 'QueueUrl' --output text 2>/dev/null)
                        if [ -n "$QUEUE_URL" ]; then
                          aws sqs delete-queue --queue-url "$QUEUE_URL" 2>&1 | tee -a /tmp/nuke-output.log
                        fi ;;
                      sns)
                        aws sns delete-topic --topic-arn "$ARN" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      s3)
                        BUCKET=$(echo "$ARN" | cut -d: -f6)
                        aws s3 rb "s3://$BUCKET" --force 2>&1 | tee -a /tmp/nuke-output.log ;;
                      elasticloadbalancing)
                        aws elbv2 delete-load-balancer --load-balancer-arn "$ARN" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      ecs)
                        RTYPE=$(echo "$ARN" | cut -d: -f6 | cut -d/ -f1)
                        case "$RTYPE" in
                          cluster) aws ecs delete-cluster --cluster "$ARN" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          service) aws ecs delete-service --cluster "$(echo "$ARN" | cut -d/ -f2)" --service "$RESOURCE_ID" --force 2>&1 | tee -a /tmp/nuke-output.log ;;
                        esac ;;
                      ecr)
                        aws ecr delete-repository --repository-name "$RESOURCE_ID" --force 2>&1 | tee -a /tmp/nuke-output.log ;;
                      secretsmanager)
                        aws secretsmanager delete-secret --secret-id "$ARN" --force-delete-without-recovery 2>&1 | tee -a /tmp/nuke-output.log ;;
                      states)
                        aws stepfunctions delete-state-machine --state-machine-arn "$ARN" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      events)
                        aws events delete-rule --name "$RESOURCE_ID" --force 2>&1 | tee -a /tmp/nuke-output.log ;;
                      logs)
                        aws logs delete-log-group --log-group-name "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      elasticache)
                        aws elasticache delete-cache-cluster --cache-cluster-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      cloudformation)
                        aws cloudformation delete-stack --stack-name "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      cognito-idp)
                        aws cognito-idp delete-user-pool --user-pool-id "$RESOURCE_ID" 2>&1 | tee -a /tmp/nuke-output.log ;;
                      iam)
                        RTYPE=$(echo "$ARN" | cut -d: -f6 | cut -d/ -f1)
                        IAM_NAME=$(echo "$ARN" | rev | cut -d/ -f1 | rev)
                        case "$RTYPE" in
                          role)
                            # Detach managed policies
                            for p in $(aws iam list-attached-role-policies --role-name "$IAM_NAME" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
                              aws iam detach-role-policy --role-name "$IAM_NAME" --policy-arn "$p" 2>/dev/null
                            done
                            # Delete inline policies
                            for p in $(aws iam list-role-policies --role-name "$IAM_NAME" --query 'PolicyNames[]' --output text 2>/dev/null); do
                              aws iam delete-role-policy --role-name "$IAM_NAME" --policy-name "$p" 2>/dev/null
                            done
                            # Remove from instance profiles
                            for ip in $(aws iam list-instance-profiles-for-role --role-name "$IAM_NAME" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null); do
                              aws iam remove-role-from-instance-profile --instance-profile-name "$ip" --role-name "$IAM_NAME" 2>/dev/null
                              aws iam delete-instance-profile --instance-profile-name "$ip" 2>/dev/null
                            done
                            aws iam delete-role --role-name "$IAM_NAME" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          user)
                            # Delete access keys
                            for k in $(aws iam list-access-keys --user-name "$IAM_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
                              aws iam delete-access-key --user-name "$IAM_NAME" --access-key-id "$k" 2>/dev/null
                            done
                            # Detach policies
                            for p in $(aws iam list-attached-user-policies --user-name "$IAM_NAME" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
                              aws iam detach-user-policy --user-name "$IAM_NAME" --policy-arn "$p" 2>/dev/null
                            done
                            # Delete inline policies
                            for p in $(aws iam list-user-policies --user-name "$IAM_NAME" --query 'PolicyNames[]' --output text 2>/dev/null); do
                              aws iam delete-user-policy --user-name "$IAM_NAME" --policy-name "$p" 2>/dev/null
                            done
                            # Remove from groups
                            for g in $(aws iam list-groups-for-user --user-name "$IAM_NAME" --query 'Groups[].GroupName' --output text 2>/dev/null); do
                              aws iam remove-user-from-group --user-name "$IAM_NAME" --group-name "$g" 2>/dev/null
                            done
                            aws iam delete-user --user-name "$IAM_NAME" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          policy)
                            # Delete non-default versions
                            for v in $(aws iam list-policy-versions --policy-arn "$ARN" --query 'Versions[?!IsDefaultVersion].VersionId' --output text 2>/dev/null); do
                              aws iam delete-policy-version --policy-arn "$ARN" --version-id "$v" 2>/dev/null
                            done
                            # Detach from all entities
                            for r in $(aws iam list-entities-for-policy --policy-arn "$ARN" --query 'PolicyRoles[].RoleName' --output text 2>/dev/null); do
                              aws iam detach-role-policy --role-name "$r" --policy-arn "$ARN" 2>/dev/null
                            done
                            for u in $(aws iam list-entities-for-policy --policy-arn "$ARN" --query 'PolicyUsers[].UserName' --output text 2>/dev/null); do
                              aws iam detach-user-policy --user-name "$u" --policy-arn "$ARN" 2>/dev/null
                            done
                            aws iam delete-policy --policy-arn "$ARN" 2>&1 | tee -a /tmp/nuke-output.log ;;
                          *) echo "    [SKIP] unknown iam type: $RTYPE" | tee -a /tmp/nuke-output.log ;;
                        esac ;;
                      *)
                        echo "    [SKIP] unsupported service: $TYPE ($ARN)" | tee -a /tmp/nuke-output.log ;;
                    esac
                done < /tmp/all-arns.txt
              fi

              echo ""
              echo "=== Cleanup complete ==="
              TOTAL=$(grep -c "would remove\|removing:" /tmp/nuke-output.log || echo 0)
              echo "Total resources processed: $TOTAL" | tee -a /tmp/nuke-output.log
        post_build:
          on-failure: CONTINUE
          commands:
            - echo "Uploading report..."
            - aws s3 cp /tmp/nuke-output.log "s3://$REPORTS_BUCKET/reports/$TIMESTAMP/nuke-output.log"
            - echo "Done."
    BUILDSPEC
  }
}

# Wait for IAM role propagation before creating the state machine.
# Step Functions validates the execution role's EventBridge permissions
# at creation time, and newly created roles need time to propagate.
resource "time_sleep" "wait_for_iam" {
  depends_on      = [aws_iam_role_policy.step_functions_orchestration]
  create_duration = "60s"
}

# Step Functions state machine
resource "aws_sfn_state_machine" "cleanup" {
  name     = "resource-cleanup"
  role_arn = aws_iam_role.step_functions_execution.arn

  depends_on = [time_sleep.wait_for_iam]

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
        Resource       = aws_sfn_activity.cleanup_approval.id
        TimeoutSeconds = 86400
        ResultPath     = "$.approval"
        Next           = "Cleanup"
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
