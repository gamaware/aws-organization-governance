# AWS Organization Governance

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-%23326CE5.svg?style=for-the-badge&logoColor=white)

## 🚀 Overview

Infrastructure as Code (IaC) repository for managing AWS Organizations,
Organizational Units (OUs), Service Control Policies (SCPs), and governance
controls across multiple AWS accounts.

## 🛠️ Prerequisites

- [tfenv](https://github.com/tfutils/tfenv) - Terraform version manager
- [AWS CLI](https://aws.amazon.com/cli/) configured with management
  account credentials
- Python 3.x (for pre-commit hooks)
- Git

## 💻 Local Development Setup

### 1. Install Terraform via tfenv

```bash
# Install tfenv (macOS)
brew install tfenv

# Install Terraform 1.14.5
tfenv install 1.14.5
tfenv use 1.14.5

# Verify
terraform version
```

### 2. Setup Pre-commit Hooks

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install pre-commit
pip install pre-commit

# Install git hooks
pre-commit install

# Test hooks
pre-commit run --all-files
```

**Pre-commit checks:**

- ✅ Terraform fmt (auto-fixes formatting)
- ✅ Terraform validate (syntax check)
- ✅ Secret detection (blocks commits with secrets)
- ✅ YAML validation
- ✅ Trailing whitespace cleanup

### 3. Configure AWS Credentials

```bash
# Configure AWS CLI with management account
aws configure

# Verify access
aws sts get-caller-identity
```

## 📁 Repository Structure

```text
.
├── .github/
│   ├── actions/
│   │   └── terraform-composite/      # Reusable Terraform workflow
│   └── workflows/
│       ├── terraform-pr.yml          # PR validation (lint, security, plan)
│       ├── terraform-plan.yml        # Auto-plan on merge to main
│       └── terraform-apply.yml       # Manual deployment trigger
├── terraform/
│   └── scps/
│       ├── backend.tf                # S3 backend with native locking
│       ├── versions.tf               # Terraform & provider versions
│       ├── providers.tf              # AWS provider configuration
│       └── main.tf                   # Dev SCP policy
├── docs/
│   └── architecture.md               # Architecture decisions & design
├── .pre-commit-config.yaml           # Pre-commit hook configuration
├── .secrets.baseline                 # Detect-secrets baseline
└── README.md
```

## 🏗️ Infrastructure

### Terraform Backend

**S3 Bucket:** `terraform-state-aws-org-governance-557690606827`

- Region: us-east-1
- Versioning: Enabled
- Encryption: AES256
- Locking: S3 native (no DynamoDB required)

### Terraform Versions

- Terraform: 1.14.5
- AWS Provider: ~> 6.0 (latest: 6.33.0)

## 🚀 Getting Started

### Initial Setup (One-time)

1. **Clone repository**

   ```bash
   git clone https://github.com/gamaware/aws-organization-governance.git
   cd aws-organization-governance
   ```

2. **Setup development environment** (see Local Development Setup above)

3. **Initialize Terraform**

   ```bash
   cd terraform/scps
   terraform init
   ```

### Development Workflow

#### Feature Branch → PR → Merge → Deploy

1. **Create feature branch**

   ```bash
   git checkout -b feature/my-change
   ```

2. **Make changes and commit**

   ```bash
   # Pre-commit hooks run automatically
   git add .
   git commit -m "Add new SCP policy"
   ```

3. **Push and create PR**

   ```bash
   git push origin feature/my-change
   # Create PR on GitHub
   ```

4. **PR checks run automatically:**
   - ✅ Linting (terraform fmt, tflint)
   - ✅ Security scan (Checkov)
   - ✅ Terraform plan preview

5. **Merge PR** (requires 1 approval + passing checks)

6. **Plan runs automatically** on merge to main

7. **Review plan** in GitHub Actions

8. **Deploy manually:**
   - Go to Actions → Terraform Apply
   - Click "Run workflow"
   - Review and confirm

### Branch Protection

Main branch is protected:

- ✅ Requires PR with 1 approval
- ✅ Requires passing status checks
- ✅ No direct pushes (admins can bypass)
- ✅ No force pushes or deletions

## 🔄 CI/CD Pipeline

### GitHub Actions Workflows

**terraform-pr.yml** (Runs on PRs)

- Terraform fmt check
- TFLint validation
- Checkov security scan
- Terraform plan preview

**terraform-plan.yml** (Runs on push to main)

- Automatic plan generation
- Plan output in Actions logs

**terraform-apply.yml** (Manual trigger)

- Requires manual approval
- Deploys infrastructure changes
- Only runs after reviewing plan

### Defense in Depth

#### Layer 1: Pre-commit (Local)

- Fast feedback before commit
- Auto-fixes formatting issues
- Blocks secrets from being committed

#### Layer 2: GitHub Actions (CI)

- Enforced validation on every PR
- Security scanning with Checkov
- Plan preview before merge

#### Layer 3: Branch Protection

- PR approval required
- Status checks must pass
- Prevents accidental direct commits

#### Layer 4: Manual Deployment

- Human review of plan output
- Explicit approval to apply
- Deployment gate via workflow_dispatch

## 🔗 Quick Links

- [Architecture Documentation](docs/architecture.md)
- [GitHub Actions](https://github.com/gamaware/aws-organization-governance/actions)
- [AWS Organizations Console](https://console.aws.amazon.com/organizations/)

## 📝 License

MIT License - see LICENSE file for details

## 👤 Author

Created by [Alex Garcia](https://github.com/gamaware)

- [LinkedIn Profile](https://www.linkedin.com/in/gamaware/)
- [Personal Website](https://alexgarcia.info/)

> **Disclaimer**: All views and opinions expressed in this repository
> are my own and do not represent the opinions of my employer.
