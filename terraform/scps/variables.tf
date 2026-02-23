variable "aws_region" {
  description = "AWS region for provider and resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-1", "us-west-2"], var.aws_region)
    error_message = "The aws_region must be an approved AWS region: us-east-1, us-east-2, us-west-1, us-west-2."
  }
}

variable "dev_ou_id" {
  description = "Dev OU ID to attach Dev SCPs to"
  type        = string

  validation {
    condition     = can(regex("^ou-[a-z0-9]+-[a-z0-9]+$", var.dev_ou_id))
    error_message = "The dev_ou_id must match the AWS OU ID format: ou-xxxx-xxxxxxxx."
  }
}
