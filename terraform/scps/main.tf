# Dev OU — Cost controls and security guardrails
resource "aws_organizations_policy" "dev_scp" {
  name        = "DevEnvironmentRestrictions"
  description = "Cost controls and security guardrails for Dev OU"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/dev-restrictions.json")
}

resource "aws_organizations_policy_attachment" "dev_scp_attachment" {
  policy_id = aws_organizations_policy.dev_scp.id
  target_id = var.dev_ou_id
}

# Dev OU — Required tagging and abuse prevention
resource "aws_organizations_policy" "dev_tagging" {
  name        = "DevTaggingAndAbusePrevention"
  description = "Require Team/Name tags and block abusable resources"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/dev-tagging-and-abuse.json")
}

resource "aws_organizations_policy_attachment" "dev_tagging_attachment" {
  policy_id = aws_organizations_policy.dev_tagging.id
  target_id = var.dev_ou_id
}

# Org root — Protect SSO trusted access
resource "aws_organizations_policy" "protect_sso" {
  name        = "ProtectSSOTrustedAccess"
  description = "Prevent disabling IAM Identity Center trusted access"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/protect-sso.json")
}

resource "aws_organizations_policy_attachment" "protect_sso_root" {
  policy_id = aws_organizations_policy.protect_sso.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# Dev OU — Security defaults (EBS encryption, IMDSv2, S3 public access)
resource "aws_organizations_policy" "security_defaults" {
  name        = "SecurityDefaults"
  description = "Enforce EBS encryption, IMDSv2, and S3 public access block"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/security-defaults.json")
}

resource "aws_organizations_policy_attachment" "security_defaults_dev" {
  policy_id = aws_organizations_policy.security_defaults.id
  target_id = var.dev_ou_id
}

# Org root — Region restriction (all accounts)
resource "aws_organizations_policy" "region_restriction" {
  name        = "RegionRestriction"
  description = "Restrict all accounts to approved AWS regions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/region-restriction.json")
}

resource "aws_organizations_policy_attachment" "region_restriction_root" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}
