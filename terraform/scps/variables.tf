variable "organization_id" {
  description = "AWS Organization ID"
  type        = string
}

variable "dev_ou_id" {
  description = "Dev OU ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
