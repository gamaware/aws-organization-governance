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

  mock_resource "aws_organizations_policy" {
    defaults = {
      id  = "p-mock12345"
      arn = "arn:aws:organizations::123456789012:policy/o-abc123def4/service_control_policy/p-mock12345"
    }
  }

  mock_resource "aws_organizations_policy_attachment" {
    defaults = {
      id = "mock-attachment-id"
    }
  }
}

variables {
  dev_ou_id = "ou-abcd-12345678"
}

run "scp_configuration" {
  command = apply

  # SCP types
  assert {
    condition     = aws_organizations_policy.dev_scp.type == "SERVICE_CONTROL_POLICY"
    error_message = "dev_scp must be SERVICE_CONTROL_POLICY"
  }

  assert {
    condition     = aws_organizations_policy.dev_tagging.type == "SERVICE_CONTROL_POLICY"
    error_message = "dev_tagging must be SERVICE_CONTROL_POLICY"
  }

  assert {
    condition     = aws_organizations_policy.protect_sso.type == "SERVICE_CONTROL_POLICY"
    error_message = "protect_sso must be SERVICE_CONTROL_POLICY"
  }

  assert {
    condition     = aws_organizations_policy.security_defaults.type == "SERVICE_CONTROL_POLICY"
    error_message = "security_defaults must be SERVICE_CONTROL_POLICY"
  }

  assert {
    condition     = aws_organizations_policy.region_restriction.type == "SERVICE_CONTROL_POLICY"
    error_message = "region_restriction must be SERVICE_CONTROL_POLICY"
  }

  # SCP names
  assert {
    condition     = aws_organizations_policy.dev_scp.name == "DevEnvironmentRestrictions"
    error_message = "dev_scp name must be DevEnvironmentRestrictions"
  }

  assert {
    condition     = aws_organizations_policy.dev_tagging.name == "DevTaggingAndAbusePrevention"
    error_message = "dev_tagging name must be DevTaggingAndAbusePrevention"
  }

  assert {
    condition     = aws_organizations_policy.protect_sso.name == "ProtectSSOTrustedAccess"
    error_message = "protect_sso name must be ProtectSSOTrustedAccess"
  }

  assert {
    condition     = aws_organizations_policy.security_defaults.name == "SecurityDefaults"
    error_message = "security_defaults name must be SecurityDefaults"
  }

  assert {
    condition     = aws_organizations_policy.region_restriction.name == "RegionRestriction"
    error_message = "region_restriction name must be RegionRestriction"
  }

  # Dev OU attachments target var.dev_ou_id
  assert {
    condition     = aws_organizations_policy_attachment.dev_scp_attachment.target_id == "ou-abcd-12345678"
    error_message = "dev_scp_attachment must target the Dev OU"
  }

  assert {
    condition     = aws_organizations_policy_attachment.dev_tagging_attachment.target_id == "ou-abcd-12345678"
    error_message = "dev_tagging_attachment must target the Dev OU"
  }

  assert {
    condition     = aws_organizations_policy_attachment.security_defaults_dev.target_id == "ou-abcd-12345678"
    error_message = "security_defaults_dev must target the Dev OU"
  }

  # Root attachments target the mocked root ID
  assert {
    condition     = aws_organizations_policy_attachment.protect_sso_root.target_id == "r-abcd"
    error_message = "protect_sso_root must target the organization root"
  }

  assert {
    condition     = aws_organizations_policy_attachment.region_restriction_root.target_id == "r-abcd"
    error_message = "region_restriction_root must target the organization root"
  }

  # Policy content contains expected Sids
  assert {
    condition     = strcontains(aws_organizations_policy.dev_scp.content, "DenyCostlyEC2Instances")
    error_message = "dev_scp must contain DenyCostlyEC2Instances statement"
  }

  assert {
    condition     = strcontains(aws_organizations_policy.dev_tagging.content, "DenyCreateWithoutTeamTag")
    error_message = "dev_tagging must contain DenyCreateWithoutTeamTag statement"
  }

  assert {
    condition     = strcontains(aws_organizations_policy.protect_sso.content, "DenyDisableSSO")
    error_message = "protect_sso must contain DenyDisableSSO statement"
  }

  assert {
    condition     = strcontains(aws_organizations_policy.security_defaults.content, "DenyDisableEBSEncryption")
    error_message = "security_defaults must contain DenyDisableEBSEncryption statement"
  }

  assert {
    condition     = strcontains(aws_organizations_policy.region_restriction.content, "DenyAllOutsideAllowedRegions")
    error_message = "region_restriction must contain DenyAllOutsideAllowedRegions statement"
  }

  # Outputs are populated (computed values resolve during apply with mocks)
  assert {
    condition     = output.organization_id != ""
    error_message = "organization_id output must not be empty"
  }

  assert {
    condition     = output.root_id != ""
    error_message = "root_id output must not be empty"
  }

  assert {
    condition     = output.dev_scp_id != ""
    error_message = "dev_scp_id output must not be empty"
  }

  assert {
    condition     = output.sso_protection_scp_id != ""
    error_message = "sso_protection_scp_id output must not be empty"
  }

  assert {
    condition     = output.dev_tagging_scp_id != ""
    error_message = "dev_tagging_scp_id output must not be empty"
  }

  assert {
    condition     = output.security_defaults_scp_id != ""
    error_message = "security_defaults_scp_id output must not be empty"
  }

  assert {
    condition     = output.region_restriction_scp_id != ""
    error_message = "region_restriction_scp_id output must not be empty"
  }
}
