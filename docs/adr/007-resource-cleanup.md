# ADR-007: Automated Resource Cleanup

## Status

Accepted

## Context

Students create AWS resources in the Dev account during the course.
After the semester ends, all student resources must be deleted to keep
the account clean and avoid ongoing costs. Manual cleanup is error-prone
and misses resources. A reliable automated solution is needed.

## Decision

Implement a two-phase cleanup automation:

1. **Deterministic deletion** via aws-nuke (ekristen fork) running in
   CodeBuild. aws-nuke handles 300+ resource types with automatic
   dependency ordering via multi-pass retry. Tag-based filtering
   targets only resources with Team tags (team-1 through team-7).

2. **AI verification** via Bedrock Opus 4.6 running in Lambda. Two
   scans: tag-based discovery (Resource Groups Tagging API) and full
   account inventory (30+ AWS APIs). Cross-references both to catch
   orphaned resources.

Orchestration via Step Functions with five stages: discovery (dry-run),
manual approval, cleanup (live), AI verification, notification.

EventBridge Scheduler triggers on the target date. Manual execution
via `aws stepfunctions start-execution` for testing.

### Alternatives Considered

- **cloud-nuke (Gruntwork)**: Fewer resource types (125+), no tag
  include filtering.
- **AWS Config auto-remediation**: AWS warns against auto-remediating
  destructive actions. Not designed for bulk cleanup.
- **Custom shell scripts**: Cannot match aws-nuke's 300+ resource
  type coverage and dependency ordering without massive maintenance.

### Reference

AWS Prescriptive Guidance: aws-nuke with EventBridge, Step Functions,
and CodeBuild architecture.

## Consequences

- Cleanup runs entirely on AWS (no local scripts or GitHub Actions).
- Manual approval gate prevents accidental deletion.
- AI verification catches resources missed by deterministic cleanup.
- Dedicated IAM roles with explicit denies on identity and audit
  services prevent cleanup from touching infrastructure.
- aws-nuke config must be maintained as new services are added.
- CloudFront distributions cannot be tag-enforced at creation (SCP
  limitation) and must be caught by the AI verification scan.
