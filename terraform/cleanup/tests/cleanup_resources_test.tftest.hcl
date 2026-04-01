# Run: printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf && terraform init -reconfigure && terraform test -verbose && rm backend_override.tf

mock_provider "aws" {
  mock_resource "aws_kms_key" {
    defaults = {
      id     = "mrk-mock1234567890"
      arn    = "arn:aws:kms:us-east-1:123456789012:key/mrk-mock1234567890"
      key_id = "mrk-mock1234567890"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:mock-topic"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "dev-cleanup-reports-123456789012"
      arn = "arn:aws:s3:::dev-cleanup-reports-123456789012"
    }
  }

  mock_resource "aws_sfn_state_machine" {
    defaults = {
      arn = "arn:aws:states:us-east-1:123456789012:stateMachine:resource-cleanup"
    }
  }

  mock_resource "aws_sfn_activity" {
    defaults = {
      id = "arn:aws:states:us-east-1:123456789012:activity:cleanup-approval"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:123456789012:function:cleanup-ai-verify"
    }
  }

  mock_resource "aws_codebuild_project" {
    defaults = {
      arn = "arn:aws:codebuild:us-east-1:123456789012:project/resource-cleanup"
    }
  }

  mock_resource "aws_scheduler_schedule" {
    defaults = {
      arn = "arn:aws:scheduler:us-east-1:123456789012:schedule/default/resource-cleanup-schedule"
    }
  }
}

mock_provider "archive" {
  mock_data "archive_file" {
    defaults = {
      output_path         = "lambda.zip"
      output_base64sha256 = "bW9ja2VkLWhhc2g="
      output_size         = 1024
    }
  }
}

mock_provider "time" {}

variables {
  account_id         = "123456789012"
  notification_email = "test@example.com"
}

run "cleanup_resources" {
  command = apply

  # S3 bucket
  assert {
    condition     = aws_s3_bucket.cleanup_reports.bucket == "dev-cleanup-reports-123456789012"
    error_message = "S3 bucket name must include the account ID"
  }

  # S3 versioning
  assert {
    condition     = aws_s3_bucket_versioning.cleanup_reports.versioning_configuration[0].status == "Enabled"
    error_message = "S3 versioning must be enabled"
  }

  # S3 lifecycle — expiration
  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.cleanup_reports.rule[0].expiration[0].days == 90
    error_message = "S3 lifecycle expiration must be 90 days"
  }

  # S3 lifecycle — noncurrent version expiration
  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.cleanup_reports.rule[0].noncurrent_version_expiration[0].noncurrent_days == 30
    error_message = "S3 noncurrent version expiration must be 30 days"
  }

  # S3 encryption
  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.cleanup_reports.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "S3 encryption must use aws:kms"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.cleanup_reports.rule).bucket_key_enabled == true
    error_message = "S3 bucket key must be enabled"
  }

  # S3 public access block
  assert {
    condition     = aws_s3_bucket_public_access_block.cleanup_reports.block_public_acls == true
    error_message = "block_public_acls must be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.cleanup_reports.block_public_policy == true
    error_message = "block_public_policy must be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.cleanup_reports.ignore_public_acls == true
    error_message = "ignore_public_acls must be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.cleanup_reports.restrict_public_buckets == true
    error_message = "restrict_public_buckets must be true"
  }

  # KMS key
  assert {
    condition     = aws_kms_key.cleanup.enable_key_rotation == true
    error_message = "KMS key rotation must be enabled"
  }

  assert {
    condition     = aws_kms_key.cleanup.deletion_window_in_days == 7
    error_message = "KMS deletion window must be 7 days"
  }

  # KMS alias
  assert {
    condition     = aws_kms_alias.cleanup.name == "alias/cleanup"
    error_message = "KMS alias must be alias/cleanup"
  }

  # SNS topic
  assert {
    condition     = aws_sns_topic.cleanup_notifications.name == "cleanup-notifications"
    error_message = "SNS topic name must be cleanup-notifications"
  }

  # SNS subscription
  assert {
    condition     = aws_sns_topic_subscription.cleanup_email.protocol == "email"
    error_message = "SNS subscription protocol must be email"
  }

  # Lambda function
  assert {
    condition     = aws_lambda_function.ai_verify.function_name == "cleanup-ai-verify"
    error_message = "Lambda function name must be cleanup-ai-verify"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.runtime == "python3.12"
    error_message = "Lambda runtime must be python3.12"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.timeout == 900
    error_message = "Lambda timeout must be 900 seconds"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.memory_size == 512
    error_message = "Lambda memory must be 512 MB"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.handler == "ai_verify.handler"
    error_message = "Lambda handler must be ai_verify.handler"
  }

  # Lambda tracing
  assert {
    condition     = aws_lambda_function.ai_verify.tracing_config[0].mode == "Active"
    error_message = "Lambda tracing must be Active"
  }

  # Lambda environment variables
  assert {
    condition     = aws_lambda_function.ai_verify.environment[0].variables["REPORTS_BUCKET"] != null
    error_message = "Lambda must have REPORTS_BUCKET env var"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.environment[0].variables["ACCOUNT_ID"] == "123456789012"
    error_message = "Lambda ACCOUNT_ID must match var.account_id"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.environment[0].variables["TEAM_TAGS"] != null
    error_message = "Lambda must have TEAM_TAGS env var"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.environment[0].variables["SNS_TOPIC_ARN"] != null
    error_message = "Lambda must have SNS_TOPIC_ARN env var"
  }

  assert {
    condition     = aws_lambda_function.ai_verify.environment[0].variables["ACCEPTED_FINDINGS"] != null
    error_message = "Lambda must have ACCEPTED_FINDINGS env var"
  }

  # CodeBuild project
  assert {
    condition     = aws_codebuild_project.cleanup.name == "resource-cleanup"
    error_message = "CodeBuild project name must be resource-cleanup"
  }

  assert {
    condition     = aws_codebuild_project.cleanup.build_timeout == 480
    error_message = "CodeBuild build timeout must be 480 minutes"
  }

  # CodeBuild environment
  assert {
    condition     = aws_codebuild_project.cleanup.environment[0].compute_type == "BUILD_GENERAL1_SMALL"
    error_message = "CodeBuild compute type must be BUILD_GENERAL1_SMALL"
  }

  assert {
    condition     = aws_codebuild_project.cleanup.environment[0].privileged_mode == false
    error_message = "CodeBuild privileged mode must be false"
  }

  # Step Functions state machine
  assert {
    condition     = aws_sfn_state_machine.cleanup.name == "resource-cleanup"
    error_message = "Step Functions state machine name must be resource-cleanup"
  }

  # Step Functions definition contains expected state names
  assert {
    condition     = strcontains(aws_sfn_state_machine.cleanup.definition, "Discovery")
    error_message = "Step Functions definition must contain Discovery state"
  }

  assert {
    condition     = strcontains(aws_sfn_state_machine.cleanup.definition, "WaitForApproval")
    error_message = "Step Functions definition must contain WaitForApproval state"
  }

  assert {
    condition     = strcontains(aws_sfn_state_machine.cleanup.definition, "Cleanup")
    error_message = "Step Functions definition must contain Cleanup state"
  }

  assert {
    condition     = strcontains(aws_sfn_state_machine.cleanup.definition, "AIVerify")
    error_message = "Step Functions definition must contain AIVerify state"
  }

  assert {
    condition     = strcontains(aws_sfn_state_machine.cleanup.definition, "NotifyComplete")
    error_message = "Step Functions definition must contain NotifyComplete state"
  }

  assert {
    condition     = strcontains(aws_sfn_state_machine.cleanup.definition, "ApprovalTimeout")
    error_message = "Step Functions definition must contain ApprovalTimeout state"
  }

  # Step Functions Activity
  assert {
    condition     = aws_sfn_activity.cleanup_approval.name == "cleanup-approval"
    error_message = "Activity name must be cleanup-approval"
  }

  # EventBridge Scheduler
  assert {
    condition     = aws_scheduler_schedule.cleanup.name == "resource-cleanup-schedule"
    error_message = "Scheduler name must be resource-cleanup-schedule"
  }

  assert {
    condition     = aws_scheduler_schedule.cleanup.schedule_expression_timezone == "America/Chicago"
    error_message = "Scheduler timezone must be America/Chicago"
  }

  # time_sleep
  assert {
    condition     = time_sleep.wait_for_iam.create_duration == "60s"
    error_message = "IAM propagation wait must be 60s"
  }

  # Outputs are non-empty
  assert {
    condition     = output.state_machine_arn != ""
    error_message = "state_machine_arn output must not be empty"
  }

  assert {
    condition     = output.reports_bucket != ""
    error_message = "reports_bucket output must not be empty"
  }

  assert {
    condition     = output.sns_topic_arn != ""
    error_message = "sns_topic_arn output must not be empty"
  }

  assert {
    condition     = output.codebuild_project != ""
    error_message = "codebuild_project output must not be empty"
  }

  assert {
    condition     = output.lambda_function != ""
    error_message = "lambda_function output must not be empty"
  }

  assert {
    condition     = output.scheduler_name != ""
    error_message = "scheduler_name output must not be empty"
  }

  assert {
    condition     = output.approval_activity_arn != ""
    error_message = "approval_activity_arn output must not be empty"
  }
}
