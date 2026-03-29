# terraform/scps

Manages AWS Organizations Service Control Policies (SCPs) and their attachments
to Organizational Units and the organization root.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.14 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | 6.33.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_organizations_policy.dev_scp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.dev_tagging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.protect_sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.region_restriction](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.security_defaults](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy_attachment.dev_scp_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.dev_tagging_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.protect_sso_root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.region_restriction_root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.security_defaults_dev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_organization.org](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws\_region | AWS region for provider and resources | `string` | `"us-east-1"` | no |
| dev\_ou\_id | Dev OU ID to attach Dev SCPs to | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| dev\_scp\_arn | Dev SCP Policy ARN |
| dev\_scp\_id | Dev SCP Policy ID |
| dev\_tagging\_scp\_arn | Dev Tagging and Abuse Prevention SCP Policy ARN |
| dev\_tagging\_scp\_id | Dev Tagging and Abuse Prevention SCP Policy ID |
| organization\_id | AWS Organization ID |
| region\_restriction\_scp\_arn | Region Restriction SCP Policy ARN |
| region\_restriction\_scp\_id | Region Restriction SCP Policy ID |
| root\_id | AWS Organization Root ID |
| security\_defaults\_scp\_arn | Security Defaults SCP Policy ARN |
| security\_defaults\_scp\_id | Security Defaults SCP Policy ID |
| sso\_protection\_scp\_arn | SSO Protection SCP Policy ARN |
| sso\_protection\_scp\_id | SSO Protection SCP Policy ID |
<!-- END_TF_DOCS -->
