variable "aws_region" {
  description = "AWS region for cleanup infrastructure"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1"], var.aws_region)
    error_message = "Cleanup infrastructure must deploy to us-east-1."
  }
}

variable "account_id" {
  description = "AWS account ID for the Dev account (cleanup target)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Account ID must be a 12-digit number."
  }
}

variable "notification_email" {
  description = "Email for SNS cleanup notifications"
  type        = string
}

variable "team_tags" {
  description = "Valid team tag values to target for cleanup"
  type        = list(string)
  default     = ["team-1", "team-2", "team-3", "team-4", "team-5", "team-6", "team-7"]
}

variable "cleanup_schedule" {
  description = "EventBridge cron expression for scheduled cleanup"
  type        = string
  default     = "at(2026-05-22T12:00:00)"
}
