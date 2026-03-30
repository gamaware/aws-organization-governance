# Accepted Findings

Triaged findings from AI cleanup verification. Each finding has a disposition:

- **fixed** — resolved in code
- **accepted-risk** — reviewed, intentionally left as-is
- **wont-fix** — not worth the complexity or out of scope

The AI verification prompt includes this file so it skips known findings.

## Fixed

| Finding | Resolution |
| --- | --- |

## Accepted Risk

| Finding | Reason |
| --- | --- |
| Default VPC and subnets remain after cleanup | AWS-managed defaults, not student-created |
| CloudTrail trails remain after cleanup | Protected by SCP, intentionally preserved |
| Cleanup infrastructure remains (Lambda, CodeBuild, S3, SNS, Step Functions) | Self-referential, filtered in aws-nuke config |
| Terraform state bucket remains | Infrastructure, not student-created |
| IAM resources excluded from aws-nuke | Too many AWS-managed roles with unique names, AI verification catches student IAM as second pass |
| CloudWatch log groups for cleanup infra remain | Filtered in inventory scan |

## Won't Fix

| Finding | Reason |
| --- | --- |

## To Fix

| Finding | Priority | Description |
| --- | --- | --- |
