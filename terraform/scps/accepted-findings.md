# Accepted Findings

Triaged findings from AI post-deployment analysis. Each finding has a disposition:

- **fixed** — resolved in code
- **accepted-risk** — reviewed, intentionally left as-is
- **wont-fix** — not worth the complexity or out of scope

The AI analysis prompt includes this file so it skips known findings and only
reports genuinely new issues.

## Fixed

| Finding | Resolution |
| --- | --- |
| Bedrock model ID wrong (`claude-sonnet-4-6-v1`) | Fixed to `us.anthropic.claude-sonnet-4-6` in PR #30 |
| Cross-region IAM for Bedrock inference profiles | Wildcard region in IAM ARNs, PR #31 |
| AI analysis not downloadable as artifact | Artifact upload added in PR #32 |
| S3 tagging blocks all bucket creation | Moved tag enforcement from `CreateBucket` to `PutBucketTagging` |
| RDS `StringNotLike` on absent condition key | Added `Null` check so deny only fires when class IS present |
| RDS restore bypasses instance class controls | Added `Restore*` actions to `DenyCostlyRDSInstances` |
| CloudTrail `PutEventSelectors` not denied | Added to `DenyCloudTrailDeletion` actions |

## Accepted Risk

| Finding | Reason |
| --- | --- |
| SCPs do not restrict root during account recovery | AWS limitation by design, not a policy flaw |
| `DenyAbusableServices` blocks `aws-marketplace:*` entirely | Intentional — Dev OU should not use marketplace |
| `DenyCloudTrailDeletion` blocks `cloudtrail:UpdateTrail` | Intentional — trail changes go through management account |
| `ArnLike` with exact ARNs on `DenyAdminPolicyAttachment` | Functionally equivalent to `ArnEquals`, cosmetic only |
| Bedrock cross-region exempt for Admin role only | Required for cross-region inference profiles used by Claude Code |
| `DenyRootUserActions` uses `StringLike` | Correct — wildcard `*` for account ID requires `StringLike` |
| `t4g.*` ARM instances allowed in EC2 restrictions | Intentional — ARM instances are cost-effective |
| Seven overlapping `ec2:RunInstances` deny conditions | Intentional defense-in-depth, developer docs explain requirements |
| `DenyAbusableServices` naming is vague | Cosmetic — Sid is clear enough in context |
| Launch Template bypass for instance type | Theoretical — requires pre-existing template with wrong type |
| `StringLike` vs `ArnLike` cosmetic difference | No functional impact |
| No EIP count limit via SCP | SCPs cannot count resources — use AWS Config rule instead |
| No CloudWatch cost control for log ingestion | Out of scope for SCPs — use CloudWatch quotas |
| No `lambda:UpdateFunctionCode` tag check | Tags enforced at create, update does not change resource cost profile |
| S3 buckets can be created without tags | AWS limitation — `CreateBucket` does not support `aws:RequestTag`. Enforce via Config rule |

## Won't Fix

| Finding | Reason |
| --- | --- |
| No `sts:AssumeRole` restriction for cross-account | Would break legitimate cross-account patterns (CI/CD, shared services) |
| No NAT Gateway restriction | Dev accounts need NAT for internet access in private subnets |
| No Bedrock/AI service block in Dev OU | Bedrock is used by CI/CD for AI analysis |
| EKS/EMR/Glue cost controls | Scope creep — these services not in use in Dev OU |
| Customer-managed policies named like `AdministratorAccess-Custom` | Edge case — permission boundaries handle this |

## To Fix

| Finding | Priority | Description |
| --- | --- | --- |
| `ec2:ModifyVolume` not size-restricted | P3 | Volumes can be resized above 100GB after creation |
| `ec2:ModifyInstanceAttribute` for instance type | P3 | Instance type changeable on stopped instances |
| IAM inline policy escalation paths | P3 | `PutUserPolicy`, `PutRolePolicy`, `CreatePolicyVersion` unblocked |
| `ec2:CopySnapshot` data exfiltration | P3 | Snapshots can be copied to another account |
| Global services missing from region `NotAction` | P3 | `sso:*`, `identitystore:*`, `securityhub:*`, `guardduty:*`, etc. |
