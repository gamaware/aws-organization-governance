output "organization_id" {
  description = "AWS Organization ID"
  value       = data.aws_organizations_organization.org.id
}

output "root_id" {
  description = "AWS Organization Root ID"
  value       = data.aws_organizations_organization.org.roots[0].id
}

output "dev_scp_id" {
  description = "Dev SCP Policy ID"
  value       = aws_organizations_policy.dev_scp.id
}

output "dev_scp_arn" {
  description = "Dev SCP Policy ARN"
  value       = aws_organizations_policy.dev_scp.arn
}

output "sso_protection_scp_id" {
  description = "SSO Protection SCP Policy ID"
  value       = aws_organizations_policy.protect_sso.id
}

output "sso_protection_scp_arn" {
  description = "SSO Protection SCP Policy ARN"
  value       = aws_organizations_policy.protect_sso.arn
}

output "dev_tagging_scp_id" {
  description = "Dev Tagging and Abuse Prevention SCP Policy ID"
  value       = aws_organizations_policy.dev_tagging.id
}

output "dev_tagging_scp_arn" {
  description = "Dev Tagging and Abuse Prevention SCP Policy ARN"
  value       = aws_organizations_policy.dev_tagging.arn
}
