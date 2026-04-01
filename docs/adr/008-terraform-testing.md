# ADR-008: Terraform Testing Strategy

## Status

Accepted

## Context

Both Terraform modules (SCPs and cleanup) had zero automated tests. Validation relied on:

- Post-deploy shell scripts (validate-deployment.sh) that check AWS API state
- CI linting (TFLint, Checkov, terraform fmt, terraform validate)
- Manual verification

This left gaps: configuration logic errors caught only after apply, no variable validation
testing, no assertion on resource properties before deployment, and no integration testing
for the cleanup module (which had zero post-deploy validation).

## Decision

Adopt a two-tier testing strategy:

1. **terraform test** (native, mocked providers) -- Unit-level configuration assertions
   that run without AWS credentials. Tests variable validation, resource properties,
   policy content, IAM structures, and output values. Uses mock_provider blocks
   (Terraform 1.7+) for fast, isolated execution. Integrated into terraform-pr.yml
   as a parallel job alongside lint-and-security.

2. **Terratest** (Go, AWS SDK v2) -- Read-only post-deploy integration tests that
   verify deployed infrastructure matches expectations. Does NOT call InitAndApply;
   instead reads Terraform outputs and validates via AWS SDK calls. Zero additional
   infrastructure cost. Integrated into terraform-cicd.yml and cleanup-cicd.yml
   after terraform apply.

## Consequences

- Faster feedback: configuration issues caught at PR time (terraform test), not after apply
- Two languages: HCL for unit tests, Go for integration tests
- Go dependency added to CI (tests/ directory with go.mod)
- Mock provider maintenance: mock defaults may need updates when resources change
- Existing validate-deployment.sh continues running alongside Terratest for SCPs
  (can be retired once Terratest proves reliable)
