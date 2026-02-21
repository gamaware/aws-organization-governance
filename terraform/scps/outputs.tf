output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.org.id
}

output "dev_scp_id" {
  description = "Dev SCP Policy ID"
  value       = aws_organizations_policy.dev_scp.id
}

output "dev_scp_arn" {
  description = "Dev SCP Policy ARN"
  value       = aws_organizations_policy.dev_scp.arn
}
