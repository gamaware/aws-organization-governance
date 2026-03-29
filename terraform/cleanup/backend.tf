terraform {
  backend "s3" {
    bucket       = "terraform-state-aws-org-governance-557690606827"
    key          = "cleanup/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
