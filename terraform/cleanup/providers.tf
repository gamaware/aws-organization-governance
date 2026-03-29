provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy  = "Terraform"
      Repository = "aws-organization-governance"
      Layer      = "cleanup"
    }
  }
}
