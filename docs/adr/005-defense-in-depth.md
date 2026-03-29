# ADR-005: Defense in Depth and Security Controls

## Status

Accepted

## Context

A single point of failure in the security pipeline could allow
unauthorized or broken SCP changes to reach production. We need
multiple independent layers of verification.

## Decision

Implement seven layers of defense:

1. **Pre-commit hooks (local)** — 26 hooks: formatting, validation,
   security scanning, linting, conventional commits.
2. **PR checks (CI)** — TFLint, Checkov, Terraform plan, quality
   checks, security scanning, CodeRabbit + Copilot AI review.
3. **Branch protection** — PR required, status checks must pass,
   CODEOWNERS review, no direct pushes to main.
4. **Deployment gate** — Manual trigger for apply/destroy.
5. **Post-deploy validation** — AWS CLI verification of SCP state.
6. **Drift detection** — Daily scheduled plan with auto-issue creation.
7. **Automated updates** — Dependabot + pre-commit autoupdate keep
   dependencies current via weekly PRs.

## Consequences

- Changes pass through multiple independent verification stages.
- No single tool failure can bypass all controls.
- Increased pipeline complexity, but each layer is independently
  testable and maintainable via composite actions.
- AI-powered code review (CodeRabbit + Copilot) catches semantic
  issues that static analysis misses (e.g., SCP union-deny conflicts).
