# ADR-006: AI-Powered Post-Deployment Validation

## Status

Accepted

## Context

Deterministic post-deployment validation scripts verify that SCPs exist,
are attached to correct targets, and contain expected policy content. However,
they cannot assess security posture holistically — identifying permission
escalation paths, SCP conflicts, missing deny statements, or incomplete
global service exemptions requires contextual reasoning.

## Decision

- Add an AI-powered analysis step after deterministic validation using
  Claude Sonnet via Amazon Bedrock.
- Use the existing GitHub Actions OIDC role (no new credentials) with an
  additional `bedrock:InvokeModel` inline policy.
- The AI step runs with `continue-on-error: true` — it is advisory and
  must never block deployments.
- The analysis script gathers SCP policy JSON files, live SCP state from
  AWS, and Terraform plan output, then sends them to Claude for review.
- Results are posted to the GitHub Actions step summary.

### What the AI Analyzes

- **Security posture**: Permission escalation paths, bypass mechanisms
- **SCP conflicts**: Conflicting deny patterns between org-root and OU SCPs
- **Best practices**: Naming conventions, condition scoping, statement breadth
- **Recommendations**: Missing deny statements, global service gaps, cost controls
- **Deployment summary**: What changed, overall assessment, action items

## Consequences

- Deployments gain a "smart review" layer that catches issues deterministic
  scripts cannot.
- Cost is negligible (~$0.03 per deploy via Bedrock Sonnet pricing).
- The AI step is non-blocking — failures in Bedrock or the analysis do not
  affect deployment success.
- Requires Claude model access enabled in the Bedrock console (one-time setup).
- The IAM role gains `bedrock:InvokeModel` permission scoped to Anthropic
  models only.
