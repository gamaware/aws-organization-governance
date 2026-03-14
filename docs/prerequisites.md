# Prerequisites

This page covers one-time AWS and GitHub setup required before deploying.
Follow these guides in order:

| Step | Guide | What it does |
| --- | --- | --- |
| 1 | [Enable SCPs](#enable-service-control-policies) (below) | Enable SCP policy type on the organization |
| 2 | [GitHub OIDC Setup](github-oidc-setup.md) | OIDC provider, IAM role, SCP/S3/Bedrock policies, GitHub secret |
| 3 | [GitHub Variables Setup](github-variables-setup.md) | Set org ID, OU ID, and region as GitHub Actions variables |
| 4 | [Local Development](../README.md#local-development-setup) | tfenv, pre-commit hooks, AWS credentials |

After completing all steps, push a Terraform change to main to trigger the
full CI/CD pipeline.

## Enable Service Control Policies

Before deploying SCPs with Terraform, you must enable the SCP policy type
on your AWS Organization. This is a one-time operation.

### Enable SCPs (One Command)

```bash
aws organizations enable-policy-type \
  --root-id $(aws organizations list-roots \
    --query 'Roots[0].Id' --output text) \
  --policy-type SERVICE_CONTROL_POLICY
```

### Verify SCPs are Enabled

```bash
aws organizations list-roots \
  --query 'Roots[0].PolicyTypes[?Type==`SERVICE_CONTROL_POLICY`].Status' \
  --output text
```

Expected output: `ENABLED`

### Why This is Required

The `aws_organizations_organization` Terraform resource cannot be safely
destroyed without removing all member accounts first. By enabling SCPs
manually and using a data source in Terraform, we avoid this issue while
still managing policies declaratively.
