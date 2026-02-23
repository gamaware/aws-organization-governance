# GitHub Variables Setup

This guide covers configuring GitHub Variables for Terraform deployments via
GitHub Actions.

## Prerequisites

- GitHub repository created
- GitHub CLI (`gh`) installed and authenticated
- Terraform variables defined in your configuration

## Required Variables

The following variables must be configured for the CI/CD pipeline:

| Variable Name | Description | Example |
| --------------- | ----------- | ------- |
| `EXPECTED_ORG_ID` | AWS Organization ID (for validation) | `o-xxxxxxxxxx` |
| `TF_VAR_dev_ou_id` | Development OU ID | `ou-xxxx-xxxxxxxx` |
| `TF_VAR_aws_region` | AWS Region | `us-east-1` |

> `TF_VAR_` prefixed variables are passed to Terraform as input variables.
> `EXPECTED_ORG_ID` is used only by post-deploy validation (not a Terraform
> variable — the org ID comes from a data source).

## Setup via GitHub CLI

```bash
gh variable set EXPECTED_ORG_ID --body "<ORGANIZATION_ID>"
gh variable set TF_VAR_dev_ou_id --body "<DEV_OU_ID>"
gh variable set TF_VAR_aws_region --body "<AWS_REGION>"
```

**Verify variables:**

```bash
gh variable list
```

Expected output:

```text
EXPECTED_ORG_ID   <ORGANIZATION_ID>
TF_VAR_dev_ou_id  <DEV_OU_ID>
TF_VAR_aws_region <AWS_REGION>
```

## Setup via GitHub UI

1. Navigate to repository Settings → Variables → Actions
2. Click "New repository variable" for each variable:
   - **Name:** `EXPECTED_ORG_ID`
     **Value:** `<ORGANIZATION_ID>`
   - **Name:** `TF_VAR_dev_ou_id`
     **Value:** `<DEV_OU_ID>`
   - **Name:** `TF_VAR_aws_region`
     **Value:** `<AWS_REGION>`

## Getting Variable Values

### Organization ID

```bash
aws organizations describe-organization \
  --query 'Organization.Id' --output text
```

### Development OU ID

```bash
aws organizations list-organizational-units-for-parent \
  --parent-id <ROOT_ID> \
  --query 'OrganizationalUnits[?Name==`Dev`].Id' \
  --output text
```

### AWS Region

Use your preferred region (e.g., `us-east-1`, `us-west-2`, `eu-west-1`)

## Updating Variables

```bash
gh variable set EXPECTED_ORG_ID --body "<NEW_VALUE>"
```

Or via GitHub UI: repository Settings → Variables → click variable → update.

## Troubleshooting

### Variable not set in workflow

- Verify variables exist: `gh variable list`
- Check variable names match exactly (case-sensitive)
- Ensure variables are set at repository level, not environment level

### Invalid organization ID

- Verify format: `o-` followed by 10 alphanumeric characters
- Check you're using the correct AWS account

## References

- [GitHub Variables](https://docs.github.com/en/actions/learn-github-actions/variables)
- [Terraform Environment Variables](https://developer.hashicorp.com/terraform/cli/config/environment-variables)
