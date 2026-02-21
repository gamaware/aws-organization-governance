# AWS Organization Governance

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-%23326CE5.svg?style=for-the-badge&logoColor=white)

## 🚀 Overview

Infrastructure as Code (IaC) repository for managing AWS Organizations, Organizational Units (OUs), Service Control Policies (SCPs), and governance controls across multiple AWS accounts.

## 📁 Repository Structure

```
.
├── .github/
│   ├── actions/
│   │   └── terraform-composite/
│   └── workflows/
│       ├── terraform-plan.yml
│       └── terraform-apply.yml
├── terraform/
│   ├── organization/
│   ├── scps/
│   └── accounts/
├── docs/
│   └── architecture.md
├── .gitignore
├── LICENSE
└── README.md
```

## 🏗️ Architecture

### Organization Structure

```
Organization (o-3ffm2cc86k)
├─ Management Account: General (557690606827)
└─ Root
   ├─ OU: Dev → Dev (311141527383)
   ├─ OU: DevOps → DevOps (626635444569)
   ├─ OU: Prod → Prod (571600856221)
   └─ OU: QA → QA (222634394903)
```

### Account Aliases

- `alex-garcia-dev` - Development environment
- `alex-garcia-devops` - DevOps/CI-CD environment
- `alex-garcia-general` - Management account
- `alex-garcia-prod` - Production environment
- `alex-garcia-qa` - QA/Testing environment

## 🛡️ Service Control Policies (SCPs)

### Dev OU SCP

Guardrails for development environment:

- ✅ Restrict to us-east-1 region only
- ✅ Allow only cost-effective instance types (t2, t3, t3a, t4g)
- ✅ Prevent leaving organization
- ✅ Block root user actions
- ✅ Prevent CloudTrail deletion
- ✅ Block Reserved Instance purchases

## 🚀 Getting Started

### Prerequisites

- AWS CLI configured with management account credentials
- Terraform >= 1.0
- GitHub CLI (gh)

### Deployment

Terraform deployment is automated via GitHub Actions. Manual deployment:

```bash
cd terraform/scps
terraform init
terraform plan
terraform apply
```

## 🔄 CI/CD Pipeline

GitHub Actions workflows handle:

- **terraform-pr.yml** - Runs on pull requests (linting, security, plan)
- **terraform-plan.yml** - Runs on merge to main (automatic plan)
- **terraform-apply.yml** - Manual trigger (deploy after review)

## 📝 License

MIT License - see LICENSE file for details

## 👤 Author

Created by [Alex Garcia](https://github.com/gamaware)

- [LinkedIn Profile](https://www.linkedin.com/in/gamaware/)
- [Personal Website](https://alexgarcia.info/)

> **Disclaimer**: All views and opinions expressed in this repository are my own and do not represent the opinions of my employer.
