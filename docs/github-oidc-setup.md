# GitHub Actions OIDC Setup Guide

This guide walks through setting up OpenID Connect (OIDC) authentication for
GitHub Actions to access AWS without storing long-lived credentials.

## Prerequisites

- AWS CLI configured with admin access
- GitHub repository created
- AWS account ID (replace `<AWS_ACCOUNT_ID>` throughout)
- GitHub organization/user and repository name (replace `<GITHUB_ORG>/<REPO_NAME>`)
- Terraform state S3 bucket name (replace `<TERRAFORM_STATE_BUCKET>`)
- Project name (replace `<PROJECT_NAME>`)

## Step 1: Create OIDC Identity Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Verify creation:**

```bash
aws iam list-open-id-connect-providers
```

Expected output:

```json
{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
        }
    ]
}
```

## Step 2: Create IAM Role with Trust Policy

```bash
aws iam create-role \
  --role-name GitHubActions-<PROJECT_NAME> \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          },
          "StringLike": {
            "token.actions.githubusercontent.com:sub": "repo:<GITHUB_ORG>/<REPO_NAME>:*"
          }
        }
      }
    ]
  }' \
  --description "Role for GitHub Actions to manage AWS Organizations"
```

**Verify role creation:**

```bash
aws iam get-role --role-name GitHubActions-<PROJECT_NAME>
```

## Step 3: Create Scoped Policy for SCP Management

> **WARNING**: Do NOT use `AWSOrganizationsFullAccess`.
> It grants `DisableAWSServiceAccess` which can break
> IAM Identity Center (SSO).

```bash
aws iam put-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-name SCPManagement \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowSCPManagement",
        "Effect": "Allow",
        "Action": [
          "organizations:CreatePolicy",
          "organizations:UpdatePolicy",
          "organizations:DeletePolicy",
          "organizations:DescribePolicy",
          "organizations:ListPolicies",
          "organizations:ListPoliciesForTarget",
          "organizations:AttachPolicy",
          "organizations:DetachPolicy",
          "organizations:ListTargetsForPolicy",
          "organizations:DescribeOrganization",
          "organizations:ListRoots",
          "organizations:ListAccounts",
          "organizations:ListAWSServiceAccessForOrganization",
          "organizations:ListTagsForResource",
          "organizations:TagResource",
          "organizations:UntagResource"
        ],
        "Resource": "*"
      },
      {
        "Sid": "DenyDangerousActions",
        "Effect": "Deny",
        "Action": [
          "organizations:DisableAWSServiceAccess",
          "organizations:EnableAWSServiceAccess",
          "organizations:DeleteOrganization",
          "organizations:LeaveOrganization",
          "organizations:RemoveAccountFromOrganization"
        ],
        "Resource": "*"
      }
    ]
  }'
```

**Verify policy:**

```bash
aws iam get-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-name SCPManagement
```

If you previously attached `AWSOrganizationsFullAccess`, remove it:

```bash
aws iam detach-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-arn \
    arn:aws:iam::aws:policy/AWSOrganizationsFullAccess
```

## Step 4: Add Inline Policy for Terraform State Access

```bash
aws iam put-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-name TerraformStateAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::<TERRAFORM_STATE_BUCKET>",
          "arn:aws:s3:::<TERRAFORM_STATE_BUCKET>/*"
        ]
      }
    ]
  }'
```

**Verify inline policy:**

```bash
aws iam get-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-name TerraformStateAccess
```

## Step 5: Add Inline Policy for Bedrock Access (AI Validation)

The post-deployment AI analysis uses Claude via Amazon Bedrock. Add this
inline policy to allow model invocation:

```bash
aws iam put-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-name BedrockModelAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowBedrockModelInvocation",
        "Effect": "Allow",
        "Action": [
          "bedrock:InvokeModel"
        ],
        "Resource": [
          "arn:aws:bedrock:*::foundation-model/anthropic.*",
          "arn:aws:bedrock:*:*:inference-profile/us.anthropic.*"
        ]
      }
    ]
  }'
```

**Verify policy:**

```bash
aws iam get-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-name BedrockModelAccess
```

**Enable Claude model access in Bedrock:**

1. Open the [Amazon Bedrock console](https://console.aws.amazon.com/bedrock/)
2. Navigate to **Bedrock configurations** → **Model access**
3. Select **Anthropic Claude Sonnet 4.6** (or the latest available model)
4. Submit use case details if prompted (one-time per account)
5. Access is granted immediately

## Step 6: Add Role ARN to GitHub Secrets

1. Get the role ARN:

```bash
aws iam get-role \
  --role-name GitHubActions-<PROJECT_NAME> \
  --query 'Role.Arn' \
  --output text
```

1. Add to GitHub via CLI:

```bash
gh secret set AWS_ROLE_ARN \
  --body "arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActions-<PROJECT_NAME>"
```

Or via GitHub UI:

1. Go to repository settings → Secrets and variables → Actions
1. Click "New repository secret"
1. Name: `AWS_ROLE_ARN`
1. Value: `arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActions-<PROJECT_NAME>`

## Step 7: Verify Setup

Test the workflow:

```bash
git commit --allow-empty -m "Test OIDC authentication"
git push
```

Check the workflow run for successful AWS authentication.

## Configuration Summary

The complete setup consists of:

1. **OIDC Provider:**
   - URL: `token.actions.githubusercontent.com`
   - Client ID: `sts.amazonaws.com`
   - Thumbprint: `6938fd4d98bab03faadb97b34396831e3780aea1`

2. **IAM Role:** `GitHubActions-<PROJECT_NAME>`
   - Trust policy: Allows GitHub Actions from specific repository
   - Inline policy: `SCPManagement` (scoped Organizations access)
   - Inline policy: `TerraformStateAccess` (S3 bucket access)
   - Inline policy: `BedrockModelAccess` (AI post-deploy analysis)

3. **GitHub Secret:** `AWS_ROLE_ARN`

## Security Best Practices

1. **Least Privilege**: Scoped SCP management + explicit deny on dangerous actions
2. **Repository Restriction**: Trust policy limits access to specific repository
3. **No Long-lived Credentials**: OIDC tokens expire automatically
4. **Audit Trail**: All actions logged in CloudTrail

## Troubleshooting

**Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"**

- Verify OIDC provider exists: `aws iam list-open-id-connect-providers`
- Check trust policy repository name matches exactly
- Ensure OIDC provider thumbprint is correct

### Access Denied during Terraform operations

- Verify managed policy is attached:
  `aws iam list-attached-role-policies --role-name GitHubActions-<PROJECT_NAME>`
- Check inline policy exists:
  `aws iam list-role-policies --role-name GitHubActions-<PROJECT_NAME>`
- Review CloudTrail logs for specific denied actions

### Error loading state AccessDenied

- Verify S3 bucket name in inline policy matches Terraform backend
- Check bucket exists and is in correct region
- Ensure bucket policy doesn't block the role

## Updating Permissions

To modify the inline policy:

```bash
aws iam put-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-name TerraformStateAccess \
  --policy-document file://updated-policy.json
```

To add additional managed policies:

```bash
aws iam attach-role-policy \
  --role-name GitHubActions-<PROJECT_NAME> \
  --policy-arn arn:aws:iam::aws:policy/<POLICY_NAME>
```

## Placeholders Reference

Replace these placeholders with your actual values:

- `<AWS_ACCOUNT_ID>`: Your AWS account ID (12 digits)
- `<GITHUB_ORG>`: Your GitHub organization or username
- `<REPO_NAME>`: Your repository name
- `<PROJECT_NAME>`: Project name (e.g., `OrganizationGovernance`)
- `<TERRAFORM_STATE_BUCKET>`: S3 bucket name for Terraform state

## References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [AWS Organizations Full Access Policy](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
