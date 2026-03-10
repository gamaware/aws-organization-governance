# ADR-004: IAM Least Privilege for GitHub Actions

## Status

Accepted

## Context

GitHub Actions needs AWS access to manage SCPs. Using
`AWSOrganizationsFullAccess` is convenient but overly permissive —
it allows deleting the organization, disabling service access, and
other dangerous operations.

## Decision

- Use **OIDC authentication** (no long-lived credentials).
- Replace `AWSOrganizationsFullAccess` with a custom
  `SCPManagement` inline policy scoped to SCP operations only.
- Add **explicit deny** on dangerous actions: `DeleteOrganization`,
  `LeaveOrganization`, `RemoveAccountFromOrganization`,
  `DisableAWSServiceAccess`, `DeregisterDelegatedAdministrator`.
- Separate `TerraformStateAccess` inline policy for S3 bucket access.
- GitHub Actions workflow permissions set at **job level** (not workflow
  level) following least-privilege principle.

## Consequences

- GitHub Actions role cannot perform dangerous organization operations
  even if compromised.
- OIDC tokens are short-lived and scoped to the repository.
- Job-level permissions ensure each job gets only what it needs
  (e.g., plan job gets `pull-requests: write`, apply job does not).
- Adding new Terraform resources may require updating the IAM policy.
