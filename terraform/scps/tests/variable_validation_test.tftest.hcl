# Run: printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf && terraform init -reconfigure && terraform test -verbose && rm backend_override.tf

mock_provider "aws" {
  mock_data "aws_organizations_organization" {
    defaults = {
      id                = "o-abc123def4"
      master_account_id = "123456789012"
      arn               = "arn:aws:organizations::123456789012:organization/o-abc123def4"
      roots = [{
        id   = "r-abcd"
        name = "Root"
        arn  = "arn:aws:organizations::123456789012:root/o-abc123def4/r-abcd"
      }]
    }
  }
}

run "valid_default_region" {
  command = plan

  variables {
    dev_ou_id = "ou-abcd-12345678"
  }
}

run "valid_us_west_2" {
  command = plan

  variables {
    aws_region = "us-west-2"
    dev_ou_id  = "ou-abcd-12345678"
  }
}

run "invalid_region" {
  command = plan

  variables {
    aws_region = "eu-west-1"
    dev_ou_id  = "ou-abcd-12345678"
  }

  expect_failures = [var.aws_region]
}

run "valid_ou_id" {
  command = plan

  variables {
    dev_ou_id = "ou-abcd-12345678"
  }
}

run "invalid_ou_id_format" {
  command = plan

  variables {
    dev_ou_id = "r-1234"
  }

  expect_failures = [var.dev_ou_id]
}

run "invalid_ou_id_empty" {
  command = plan

  variables {
    dev_ou_id = ""
  }

  expect_failures = [var.dev_ou_id]
}
