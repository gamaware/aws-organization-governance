# ADR-002: Terraform Backend and State Management

## Status

Accepted

## Context

Terraform state must be stored remotely for team collaboration and CI/CD.
Options include S3 + DynamoDB, S3 with native locking (Terraform 1.10+),
Terraform Cloud, or other backends.

## Decision

- Use **S3 backend with native locking** (`use_lockfile = true`).
- No DynamoDB table required — simpler infrastructure and lower cost.
- AES256 encryption enabled on the bucket.
- S3 versioning enabled for state history and recovery.
- State access scoped via `TerraformStateAccess` inline IAM policy on
  the GitHub Actions role.

## Consequences

- Requires Terraform 1.10+ (we use 1.14.5).
- Automatic cleanup of stale locks without DynamoDB TTL management.
- Single S3 bucket to manage instead of S3 + DynamoDB.
- State history available via S3 versioning for rollback scenarios.
