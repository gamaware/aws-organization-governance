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
- **PR workflow** (`terraform-pr.yml`) runs lint + security scan + plan
  preview on every PR that changes terraform files.
- **CI/CD workflow** (`terraform-cicd.yml`) triggers on push to main:
  plan runs automatically, then apply job pauses at `production`
  environment gate for reviewer approval. Apply reuses the saved plan
  artifact (no re-plan).
- **Destroy** is manual only via `workflow_dispatch`. Runs
  `terraform plan -destroy` preview, pauses at environment gate, then
  destroys on approval.
- **Concurrency controls** ensure deployment workflows (CI/CD, drift
  detection) share a single concurrency group (`terraform-state`) to
  prevent parallel state operations. PR workflows use a separate
  per-PR group with cancel-in-progress for stale checks.
- **Post-deploy validation** verifies SCPs exist, are attached to correct
  targets, and contain expected policy content via AWS CLI.
- **Post-destroy validation** confirms no orphaned SCPs remain.
- **Drift detection** runs daily at 9 AM UTC, creates GitHub issue if
  infrastructure has drifted from state.

## Consequences

- No accidental applies — environment approval required before apply.
- Plan artifact reuse — apply uses the exact plan that was reviewed.
- Destroy requires explicit manual trigger plus environment approval
  (two gates).
- Full audit trail via Git history, GitHub Actions logs, and environment
  deployment history.
- Drift is detected within 24 hours and tracked as a GitHub issue.
- Validation catches deployment failures that Terraform exit codes miss
  (e.g., SCP created but not attached correctly).
- Shared concurrency group on deployment workflows prevents state
  corruption from parallel runs.
