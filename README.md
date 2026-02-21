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
- ✅ Markdown linting (auto-fixes formatting)
- ✅ GitHub Actions validation (workflow syntax)
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
│   │   └── terraform-composite/      # Reusable Terraform action
│   ├── workflows/
│   │   ├── terraform-cicd.yml        # Unified CI/CD (plan/apply/destroy)
│   │   ├── terraform-pr.yml          # PR validation (lint, security, plan)
│   │   └── update-pre-commit-hooks.yml  # Weekly hook updates
│   └── dependabot.yml                # Weekly dependency updates
├── terraform/
│   └── scps/
│       ├── backend.tf                # S3 backend with native locking
│       ├── versions.tf               # Terraform & provider versions
│       ├── providers.tf              # AWS provider configuration
│       ├── variables.tf              # Input variables
│       ├── terraform.tfvars.example  # Variable template
│       ├── import.tf                 # Organization import block
│       ├── main.tf                   # Organization + Dev SCP
│       └── outputs.tf                # Output values
├── docs/
│   ├── architecture.md               # Architecture & design decisions
│   ├── github-oidc-setup.md          # OIDC authentication setup
│   └── github-variables-setup.md     # GitHub Variables configuration
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

3. **Setup AWS OIDC Authentication**

   Follow the [GitHub OIDC Setup Guide](docs/github-oidc-setup.md) to configure
   OIDC authentication for GitHub Actions.

4. **Configure GitHub Variables**

   Follow the [GitHub Variables Setup Guide](docs/github-variables-setup.md) to
   configure required Terraform variables.

5. **Configure Terraform variables locally**

   ```bash
   cd terraform/scps
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

   **Note:** `terraform.tfvars` is gitignored and never committed to the repo.

6. **Initialize Terraform**

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
   - Go to Actions → Terraform CI/CD
   - Click "Run workflow"
   - Select action: `plan`, `apply`, or `destroy`
   - Review and confirm

### Deployment Options

**Plan:**

- Generate execution plan
- Review changes before applying
- No infrastructure modifications

**Apply:**

- Deploy infrastructure changes
- Requires plan review first
- Updates AWS resources

**Destroy:**

- Remove managed resources
- Use with caution
- Requires explicit confirmation

### Branch Protection

Main branch is protected:

- ✅ Requires PR with 1 approval
- ✅ Requires passing status checks
- ✅ No direct pushes (admins can bypass)
- ✅ No force pushes or deletions

## 🔄 CI/CD Pipeline

### GitHub Actions Workflows

**terraform-cicd.yml** (Unified CI/CD)

- **On PR:** Runs plan automatically
- **On push to main:** Runs plan automatically
- **Manual trigger:** Dropdown with 3 options:
  - `plan` - Generate execution plan
  - `apply` - Deploy infrastructure changes
  - `destroy` - Remove managed resources
- Plan output displayed in GitHub UI
- Artifact sharing between plan/apply jobs
- Color output enabled

**terraform-pr.yml** (PR Validation)

- Terraform fmt check
- TFLint validation
- Checkov security scan
- Terraform plan preview

**update-pre-commit-hooks.yml** (Weekly Maintenance)

- Runs every Sunday
- Updates pre-commit hook versions
- Auto-creates PR with changes

**Dependabot** (Weekly Maintenance)

- Updates GitHub Actions versions
- Updates Terraform provider versions
- Auto-creates PRs

### Authentication

**OIDC (OpenID Connect):**

- No long-lived AWS credentials stored in GitHub
- Temporary credentials via AWS STS AssumeRoleWithWebIdentity
- Role: `GitHubActions-OrganizationGovernance`
- Permissions: AWSOrganizationsFullAccess + S3 state access
- Repository-scoped trust policy

See [GitHub OIDC Setup Guide](docs/github-oidc-setup.md) for details.

### Defense in Depth

#### Layer 1: Pre-commit (Local)

- Fast feedback before commit
- Auto-fixes formatting issues (Terraform, Markdown)
- Blocks secrets from being committed
- Validates YAML and GitHub Actions workflows

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

#### Layer 5: Automated Updates

- Weekly dependency updates (Dependabot)
- Weekly hook updates (pre-commit autoupdate)
- Auto-created PRs for review

## 🔗 Quick Links

- [Architecture Documentation](docs/architecture.md)
- [GitHub OIDC Setup Guide](docs/github-oidc-setup.md)
- [GitHub Variables Setup Guide](docs/github-variables-setup.md)
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
