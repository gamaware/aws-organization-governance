provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      ManagedBy  = "Terraform"
      Repository = "aws-organization-governance"
      Layer      = "cleanup"
    }
  }
}
