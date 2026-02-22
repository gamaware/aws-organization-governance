# Prerequisites

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
