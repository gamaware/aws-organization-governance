output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.cleanup.arn
}

output "reports_bucket" {
  description = "S3 bucket for cleanup reports"
  value       = aws_s3_bucket.cleanup_reports.id
}

output "sns_topic_arn" {
  description = "SNS topic ARN for cleanup notifications"
  value       = aws_sns_topic.cleanup_notifications.arn
}

output "codebuild_project" {
  description = "CodeBuild project name"
  value       = aws_codebuild_project.cleanup.name
}

output "lambda_function" {
  description = "AI verification Lambda function name"
  value       = aws_lambda_function.ai_verify.function_name
}

output "scheduler_name" {
  description = "EventBridge Scheduler name"
  value       = aws_scheduler_schedule.cleanup.name
}

output "approval_activity_arn" {
  description = "Step Functions Activity ARN for cleanup approval"
  value       = aws_sfn_activity.cleanup_approval.id
}
