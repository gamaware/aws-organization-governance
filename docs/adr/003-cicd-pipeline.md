# ADR-003: CI/CD Pipeline and Deployment Strategy

## Status

Accepted

## Context

SCP changes affect security boundaries across all AWS accounts. The
deployment pipeline must balance speed with safety, preventing accidental
or unauthorized changes.

## Decision

- **Composite actions** encapsulate reusable logic (terraform operations,
  lint/security, post-deploy validation, drift detection).
- **PR workflow** runs lint + security scan + plan preview on every PR.
- **CI/CD workflow** auto-plans on merge to main, requires manual trigger
  for apply/destroy via `workflow_dispatch`.
- **Post-deploy validation** verifies SCPs exist, are attached to correct
  targets, and contain expected policy content via AWS CLI.
- **Post-destroy validation** confirms no orphaned SCPs remain.
- **Drift detection** runs daily at 9 AM UTC, creates GitHub issue if
  infrastructure has drifted from state.

## Consequences

- No accidental applies — manual trigger required for destructive actions.
- Full audit trail via Git history and GitHub Actions logs.
- Drift is detected within 24 hours and tracked as a GitHub issue.
- Validation catches deployment failures that Terraform exit codes miss
  (e.g., SCP created but not attached correctly).
