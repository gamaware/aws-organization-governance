# AWS Organization Architecture

## Organization Structure

```
Organization (o-3ffm2cc86k)
├─ Management Account: General (557690606827)
│  └─ Alias: alex-garcia-general
│
└─ Root
   ├─ OU: Dev (ou-srmc-f52jl8so)
   │  └─ Dev Account (311141527383)
   │     └─ Alias: alex-garcia-dev
   │
   ├─ OU: DevOps (ou-srmc-yio2u8xw)
   │  └─ DevOps Account (626635444569)
   │     └─ Alias: alex-garcia-devops
   │
   ├─ OU: Prod (ou-srmc-ht4bzwfc)
   │  └─ Prod Account (571600856221)
   │     └─ Alias: alex-garcia-prod
   │
   └─ OU: QA (ou-srmc-3swc55qp)
      └─ QA Account (222634394903)
         └─ Alias: alex-garcia-qa
```

## Service Control Policies (SCPs)

### Dev OU SCP

Applied to: Dev OU (ou-srmc-f52jl8so)

**Guardrails:**
- Restrict to us-east-1 region only
- Allow only cost-effective EC2 instances (t2, t3, t3a, t4g families)
- Allow only cost-effective RDS instances (db.t2, db.t3, db.t4g families)
- Prevent leaving organization
- Block root user actions
- Prevent CloudTrail deletion/modification
- Block Reserved Instance purchases

**Purpose:** Enable developers to experiment and build while maintaining cost controls and security guardrails.

## IAM Strategy

### Dev Account

**Group:** Developers
**Policy:** PowerUserAccess + Limited IAM permissions
**Members:** 7 developers

**Permissions:**
- Full access to AWS services (Lambda, S3, EC2, RDS, etc.)
- Can create IAM roles for applications
- Can pass roles to services
- Cannot modify users, groups, or their own permissions

**Guardrails (via SCP):**
- Even with PowerUser access, cannot violate SCP restrictions
- Cannot launch expensive resources
- Cannot use regions outside us-east-1
- Cannot disable audit logging

## Deployment Strategy

### Infrastructure as Code

- **Tool:** Terraform 1.14.5
- **Provider:** AWS ~> 6.0 (latest: 6.33.0)
- **Backend:** S3 with native locking (no DynamoDB)
- **Version Control:** GitHub
- **CI/CD:** GitHub Actions

### Terraform Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-aws-org-governance-557690606827"
    key          = "scps/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true  # S3 native locking (Terraform 1.14+)
  }
}
```

**Why S3 native locking?**
- No DynamoDB table required (simpler infrastructure)
- Built-in to Terraform 1.14+
- Automatic cleanup of stale locks
- Lower cost (no DynamoDB charges)

### Workflow

```mermaid
graph LR
    A[Feature Branch] --> B[Create PR]
    B --> C[CI Checks]
    C --> D[Approve & Merge]
    D --> E[Auto Plan]
    E --> F[Review Plan]
    F --> G[Manual Apply]
    G --> H[Deployed]
```

**Steps:**
1. Create feature branch
2. Make changes, commit (pre-commit hooks run)
3. Push and create PR
4. CI runs: lint, security scan, plan preview
5. Approve and merge PR
6. Plan runs automatically on main
7. Review plan output in Actions
8. Manually trigger apply workflow
9. Infrastructure deployed

### Environments

- **plan:** No approval required (preview only)
- **production:** Requires manual approval before apply

## Security Controls

### Defense in Depth Layers

**1. Pre-commit Hooks (Local)**
- Terraform fmt & validate
- Secret detection (detect-secrets)
- YAML validation
- Blocks commits with issues

**2. GitHub Actions (CI)**
- TFLint (Terraform best practices)
- Checkov (security & compliance)
- Terraform plan preview
- Runs on every PR

**3. Branch Protection**
- Requires PR approval
- Status checks must pass
- No direct commits to main
- No force pushes

**4. Manual Deployment Gate**
- Human review required
- Explicit workflow trigger
- Plan review before apply

### Preventive Controls (SCPs)
- Region restrictions
- Instance type restrictions
- Root user blocking
- Organization protection
- CloudTrail protection

### Detective Controls
- CloudTrail (cannot be disabled via SCP)
- AWS Config (recommended)
- Security Hub (recommended)
- GitHub Actions audit logs

### Compliance
- All infrastructure changes tracked in Git
- All deployments require approval
- Security scanning on every change
- Immutable state history (S3 versioning)
