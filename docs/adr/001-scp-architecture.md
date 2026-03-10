# ADR-001: SCP Architecture and Attachment Strategy

## Status

Accepted

## Context

AWS Organizations supports Service Control Policies (SCPs) attached at
different levels: organization root, OU, or individual account. We need
a strategy for how to organize and attach SCPs across our organization.

## Decision

- **Org-root SCPs** for organization-wide security controls that apply
  to all accounts (region restriction, SSO protection).
- **OU-level SCPs** for environment-specific restrictions (dev cost
  controls, tagging enforcement, abuse prevention).
- Each SCP is a separate JSON file in `terraform/scps/policies/` loaded
  via `file()` in Terraform.
- Use `NotAction` pattern for region restriction to properly exempt
  global services (IAM, STS, Route 53, CloudFront, etc.) instead of
  blanket `Action: *` deny which blocks global services.
- SCP JSON files use kebab-case naming, Terraform resources use
  snake\_case, and AWS policy names use PascalCase.

## Consequences

- Clear separation between org-wide and OU-specific controls.
- Avoids SCP union-deny conflicts (a blanket deny at OU level would
  override NotAction exemptions at org root).
- Each SCP can be independently managed and tested.
- Adding a new OU requires only attaching existing org-root SCPs and
  creating OU-specific ones.
