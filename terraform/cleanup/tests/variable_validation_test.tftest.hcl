# Run: printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf && terraform init -reconfigure && terraform test -verbose && rm backend_override.tf

mock_provider "aws" {}

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

run "valid_defaults" {
  command = plan

  variables {
    account_id         = "123456789012"
    notification_email = "test@example.com"
  }
}

run "invalid_region" {
  command = plan

  variables {
    aws_region         = "us-west-2"
    account_id         = "123456789012"
    notification_email = "test@example.com"
  }

  expect_failures = [var.aws_region]
}

run "valid_account_id" {
  command = plan

  variables {
    account_id         = "123456789012"
    notification_email = "test@example.com"
  }
}

run "invalid_account_id_short" {
  command = plan

  variables {
    account_id         = "12345678901"
    notification_email = "test@example.com"
  }

  expect_failures = [var.account_id]
}

run "invalid_account_id_letters" {
  command = plan

  variables {
    account_id         = "55769060682a"
    notification_email = "test@example.com"
  }

  expect_failures = [var.account_id]
}

run "custom_team_tags" {
  command = plan

  variables {
    account_id         = "123456789012"
    notification_email = "test@example.com"
    team_tags          = ["team-a", "team-b"]
  }
}

run "custom_schedule" {
  command = plan

  variables {
    account_id         = "123456789012"
    notification_email = "test@example.com"
    cleanup_schedule   = "rate(7 days)"
  }
}
