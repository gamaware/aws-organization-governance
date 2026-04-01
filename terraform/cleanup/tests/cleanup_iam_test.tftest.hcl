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

run "iam_configuration" {
  command = apply

  # CodeBuild role
  assert {
    condition     = aws_iam_role.codebuild_execution.name == "cleanup-codebuild-execution"
    error_message = "CodeBuild role name must be cleanup-codebuild-execution"
  }

  assert {
    condition     = strcontains(aws_iam_role.codebuild_execution.assume_role_policy, "codebuild.amazonaws.com")
    error_message = "CodeBuild trust policy must reference codebuild.amazonaws.com"
  }

  # CodeBuild policy content
  assert {
    condition     = strcontains(aws_iam_role_policy.codebuild_cleanup.policy, "DenyIAMEscalation")
    error_message = "CodeBuild policy must contain DenyIAMEscalation"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.codebuild_cleanup.policy, "DenyOrgAndAudit")
    error_message = "CodeBuild policy must contain DenyOrgAndAudit"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.codebuild_cleanup.policy, "organizations:*")
    error_message = "CodeBuild policy must deny organizations:*"
  }

  # Lambda role
  assert {
    condition     = aws_iam_role.lambda_execution.name == "cleanup-lambda-execution"
    error_message = "Lambda role name must be cleanup-lambda-execution"
  }

  assert {
    condition     = strcontains(aws_iam_role.lambda_execution.assume_role_policy, "lambda.amazonaws.com")
    error_message = "Lambda trust policy must reference lambda.amazonaws.com"
  }

  # Lambda policy content
  assert {
    condition     = strcontains(aws_iam_role_policy.lambda_verify.policy, "bedrock:InvokeModel")
    error_message = "Lambda policy must allow bedrock:InvokeModel"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.lambda_verify.policy, "xray:PutTraceSegments")
    error_message = "Lambda policy must allow xray:PutTraceSegments"
  }

  # Step Functions role
  assert {
    condition     = aws_iam_role.step_functions_execution.name == "cleanup-stepfunctions-execution"
    error_message = "Step Functions role name must be cleanup-stepfunctions-execution"
  }

  assert {
    condition     = strcontains(aws_iam_role.step_functions_execution.assume_role_policy, "states.amazonaws.com")
    error_message = "Step Functions trust policy must reference states.amazonaws.com"
  }

  # Step Functions policy content
  assert {
    condition     = strcontains(aws_iam_role_policy.step_functions_orchestration.policy, "codebuild:StartBuild")
    error_message = "Step Functions policy must allow codebuild:StartBuild"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.step_functions_orchestration.policy, "lambda:InvokeFunction")
    error_message = "Step Functions policy must allow lambda:InvokeFunction"
  }

  # Scheduler role
  assert {
    condition     = aws_iam_role.scheduler_execution.name == "cleanup-scheduler-execution"
    error_message = "Scheduler role name must be cleanup-scheduler-execution"
  }

  assert {
    condition     = strcontains(aws_iam_role.scheduler_execution.assume_role_policy, "scheduler.amazonaws.com")
    error_message = "Scheduler trust policy must reference scheduler.amazonaws.com"
  }

  # Scheduler policy content
  assert {
    condition     = strcontains(aws_iam_role_policy.scheduler_invoke.policy, "states:StartExecution")
    error_message = "Scheduler policy must allow states:StartExecution"
  }
}
