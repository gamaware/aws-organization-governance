# CLAUDE.md — Project Instructions for Claude Code

This file is automatically loaded into context when Claude Code starts a conversation
in this repository. It defines the conventions, rules, and structure that must be followed.

## Repository Overview

Infrastructure as Code (IaC) repository for managing AWS Organizations governance:
Service Control Policies (SCPs), Organizational Units (OUs), and security controls
across multiple AWS accounts. Uses Terraform with S3 backend and GitHub Actions CI/CD.

## Repository Structure

```text
.github/
  actions/                    # Composite actions (terraform, drift, validation, lint)
  scripts/                    # Shell scripts called by composite actions
  workflows/                  # CI/CD pipelines
  ISSUE_TEMPLATE/             # Issue templates
  PULL_REQUEST_TEMPLATE.md    # PR template
  copilot-instructions.md     # Copilot code review custom instructions
terraform/scps/
  policies/                   # SCP JSON policy files
  main.tf                     # SCP resources and attachments
  data.tf                     # Organization data source
  variables.tf                # Input variables
  outputs.tf                  # Output values
  backend.tf                  # S3 backend with native locking
  providers.tf                # AWS provider configuration
  versions.tf                 # Terraform and provider versions
  terraform.tfvars.example    # Variable template
terraform/cleanup/
  main.tf                     # Cleanup orchestration resources
  iam.tf                      # IAM roles and policies for cleanup
  lambda/                     # Lambda function source code
  nuke-config.yaml.tpl        # aws-nuke configuration template
terraform/scps/tests/             # Native terraform test files (mocked)
terraform/cleanup/tests/          # Native terraform test files (mocked)
tests/                            # Terratest Go integration tests
docs/
  adr/                        # Architecture Decision Records
  architecture.md             # Architecture and design decisions
  github-oidc-setup.md        # OIDC authentication setup
  github-variables-setup.md   # GitHub Variables configuration
  prerequisites.md            # One-time SCP enablement
  student-guide.md            # Dev account user guide
.claude/
  settings.json               # Claude Code hooks configuration
  hooks/                      # Hook scripts (post-edit, protect-generated)
  skills/new-scp/             # Scaffold new SCP (/new-scp skill)
```

### SCP Naming

- Terraform resource names: `snake_case` (e.g., `dev_scp`, `protect_sso`)
- AWS policy names: `PascalCase` (e.g., `DevEnvironmentRestrictions`, `ProtectSSOTrustedAccess`)
- JSON policy files: `kebab-case` in `terraform/scps/policies/` (e.g., `dev-restrictions.json`)
- Statement Sids: `PascalCase` starting with `Deny` (e.g., `DenyAllOutsideUSEast1`)

### SCP Architecture

- **Dev OU SCPs**: Cost controls, instance restrictions, tagging enforcement, abuse prevention
- **Org root SCPs**: Organization-wide security (SSO protection, region restriction)
- Each SCP is a separate JSON file loaded via `file()` in `main.tf`
- SCP JSON must be valid AWS IAM policy syntax with `Version` and `Statement` array

### Cleanup Module

- **Location:** `terraform/cleanup/`
- **Key files:** `main.tf`, `iam.tf`, `lambda/` (Lambda function source),
  `nuke-config.yaml.tpl` (aws-nuke config template)
- **Naming conventions:** Same as SCPs — Terraform resources in `snake_case`, AWS names in `PascalCase`,
  files in `kebab-case`
- **CI/CD:** Separate `cleanup-cicd.yml` workflow (not part of the main SCP pipeline)
- **Testing:** `cleanup-test-infra.sh` script for validating cleanup infrastructure

## Git Workflow

### Commits

- **Conventional commits required** — enforced by `conventional-pre-commit` hook.
- Format: `type: description` (e.g., `fix:`, `feat:`, `docs:`, `chore:`, `ci:`).
- Never commit directly to `main` — enforced by `no-commit-to-branch` hook.
- Always work on a feature branch and create a PR.
- Do NOT add `Co-Authored-By` watermarks or any Claude/AI attribution to commits,
  code, or content. Ever.

### Pull Requests

- All changes go through PRs — no direct pushes to `main`.
- Squash merge only (merge commits and rebase disabled).
- CodeRabbit and GitHub Copilot auto-review all PRs — address their comments before merging.
- All required status checks must pass before merge.
- At least 1 approving review required (CODEOWNERS enforced).
- All review conversations must be resolved before merge.
- Use `--admin` flag to bypass branch protection when necessary.

## Pre-commit Hooks

All hooks must pass before committing. Install with `pre-commit install`.

### Hooks in use

- **General**: trailing-whitespace, end-of-file-fixer, check-yaml, check-json,
  check-added-large-files (1MB), check-merge-conflict, detect-private-key,
  check-executables-have-shebangs, check-shebang-scripts-are-executable,
  check-symlinks, check-case-conflict, no-commit-to-branch (main).
- **Secrets**: detect-secrets (with `.secrets.baseline`), gitleaks.
- **Terraform**: terraform\_fmt, terraform\_validate, terraform\_tflint,
  terraform\_docs, terraform\_trivy, terraform\_checkov.
- **Shell**: shellcheck (severity: warning), shellharden.
- **Markdown**: markdownlint with `--fix`.
- **Prose**: Vale with write-good (passive voice, weasel words) and proselint (grammar, usage).
- **GitHub Actions**: actionlint, zizmor (security analysis).
- **Commits**: conventional-pre-commit (commit-msg stage).

## Claude Code Hooks

Hooks in `.claude/settings.json` automate deterministic actions:

- **Post-edit** (`post-edit.sh`): Uses `$TOOL_INPUT_FILE_PATH` to detect the
  edited file. After every Edit/Write, auto-runs:
  - `shellharden --replace` and `chmod +x` on `.sh` files (only if shebang present)
  - `markdownlint --fix` on `.md` files
  - `terraform fmt` on `.tf` files
  - JSON validation on `policies/*.json` files
- **Protect managed files** (`protect-generated.sh`): Blocks edits (exit code 2) to:
  - `terraform/scps/README.md` — auto-generated by terraform-docs
  - `.secrets.baseline` — managed by detect-secrets
  - `.terraform.lock.hcl` — managed by `terraform init`

## Linting Policy

### Absolute rule: NO suppressions on our own code

- All default linting rules are enforced. Fix violations, never suppress them.
- Markdownlint config: MD013 line length at 120 characters, tables exempt.
  That is the ONLY customization in `.markdownlint.yaml`.
- `.markdownlintignore` excludes auto-generated READMEs: `terraform/scps/README.md`
  and `terraform/cleanup/README.md`.

### Allowed exclusions

- `terraform_checkov` skips `CKV_AWS_274` (organizational SCPs are deny-only by design).
- These are the ONLY acceptable exclusions. Do not add more without explicit approval.

## Shell Scripts

- Must pass both `shellcheck` and `shellharden`.
- Quote all variables. Prefer `"$var"` over `"${var}"` — only use braces when needed
  (e.g., `"${var}_suffix"`).
- Use arrays properly for word splitting scenarios.
- Scripts must have shebangs (`#!/usr/bin/env bash`) and executable permissions.
- Editing tools may strip executable permissions — verify with `git diff --summary`
  and restore with `chmod +x <script>` if needed.

## Markdown

- Line length limit: 120 characters (MD013).
- Tables are exempt from line length.
- Table separator lines must have spaces around pipes: `| --- | --- |` not `|---|---|`.
- Use ATX headings (`#`), not bold text as headings.
- Fenced code blocks must specify a language.

## CI/CD Pipelines

### How workflows relate

Workflows are separate because GitHub Actions uses workflows as the unit of
triggering — each needs its own trigger, permissions, and concurrency group.
The quality gate ties them together without coupling:

```text
PR opened (terraform/**)
├── ci-checks.yml         → repo-wide: markdown, shell, YAML, structure, Semgrep, Trivy
└── terraform-pr.yml      → TF-specific: TFLint, Checkov, terraform test, plan

Push to main (terraform/scps/**)
├── ci-checks.yml         → same repo-wide checks
└── terraform-cicd.yml    → quality gate polls ci-checks, then plan → apply → Terratest

Push to main (terraform/cleanup/**)
├── ci-checks.yml         → same repo-wide checks
└── cleanup-cicd.yml      → plan → apply (cross-account) → Terratest
```

### terraform-cicd.yml

Main SCP pipeline — push to main triggers plan → apply pauses at `production`
environment gate → reviewer approves → apply uses saved plan artifact (no re-plan).
After apply: deterministic validation (`validate-deployment.sh`), AI analysis via
Bedrock, then Terratest integration tests (`go test -run TestSCPs`).
AI analysis output is uploaded as artifact `ai-deployment-analysis` (30-day retention).
To review findings: `gh run download <RUN_ID> -n ai-deployment-analysis` then read
`ai-analysis.md`. The AI prompt includes `terraform/scps/accepted-findings.md` so it
skips previously triaged findings and only reports new issues. After reviewing new
findings, triage them into the accepted findings file (fixed, accepted-risk, wont-fix,
or to-fix). Destroy is manual only via `workflow_dispatch` with `plan -destroy` preview.
Concurrency group (`terraform-state`) prevents simultaneous Terraform runs.

### cleanup-cicd.yml

Cleanup module pipeline — push to main triggers plan → apply pauses at `production`
environment gate → reviewer approves → apply uses saved plan artifact (includes
`.terraform.lock.hcl` for consistency). After apply, Terratest integration tests
(`go test -run TestCleanup`) verify deployed resources via cross-account AWS SDK
calls. Concurrency group (`cleanup-terraform-state`) is separate from the SCP
pipeline to allow independent deployments.

### terraform-pr.yml

PR checks for Terraform changes — three parallel jobs: lint and security scan
(TFLint, Checkov, `terraform fmt`), terraform test with mocked providers (matrix
strategy runs both SCPs and cleanup modules), and `terraform plan` with PR comment.
The plan job depends on both lint and test jobs passing first. No AWS credentials
needed for the test job (mocked providers only).

### ci-checks.yml

Repo-wide quality and security — runs on every PR and push to main (no path filtering).
10 parallel jobs: markdownlint, link checking, shellcheck, yamllint, zizmor (actions
security), file structure validation, README quality check, Vale (prose linting),
Semgrep SAST, and Trivy IaC scanning. Each job posts a `$GITHUB_STEP_SUMMARY`.
The terraform-cicd quality gate polls this single workflow before allowing apply.

### drift-detection.yml

Daily at 9 AM UTC — detects config drift, creates GitHub issue.

### update-pre-commit-hooks.yml

Weekly auto-update of pre-commit hook versions via PR.

### Dependabot

Monitors GitHub Actions and Terraform provider dependencies weekly.

## Testing

### terraform test (native, mocked)

Unit-level configuration tests using Terraform's built-in test framework with mocked
providers. No AWS credentials required.

**Location:** `terraform/<module>/tests/*.tftest.hcl`

**Run locally:**

```bash
cd terraform/scps
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
terraform init -reconfigure
terraform test -verbose
rm backend_override.tf
```

**CI:** Runs as `terraform-test` job in `terraform-pr.yml` (parallel with lint-and-security).

**What it tests:**

- Variable validation (valid/invalid inputs)
- Resource configuration (names, types, properties)
- SCP policy content (expected Statement IDs)
- IAM role trust policies and inline policy structure
- Output values

### Terratest (Go integration tests)

Read-only post-deploy verification using AWS SDK v2. Tests do not create or destroy
infrastructure -- they validate already-deployed resources via API calls.

**Location:** `tests/` at repo root

**Run locally:**

```bash
cd tests
export CLEANUP_ACCOUNT_ID=<dev-account-id>
go test -v -timeout 10m ./...
```

**CI:** Runs after terraform apply in `terraform-cicd.yml` and `cleanup-cicd.yml`.

**What it tests:**

- SCPs: policy existence, attachment to correct OUs, output format
- Cleanup: Lambda config, Step Functions structure, S3 bucket settings, KMS, IAM roles,
  CodeBuild project, EventBridge scheduler

## Code Review

- **CodeRabbit** — Auto-reviews via `.coderabbit.yaml`. Path-specific instructions
  for Terraform, workflows, and scripts.
- **GitHub Copilot** — Auto-reviews via ruleset. Custom instructions in
  `.github/copilot-instructions.md`.
- Both reviewers run on every PR. Address comments from both before merging.
- Reviewers may comment on issues already fixed in subsequent commits.
  Verify current file state before acting — stale comments can be dismissed.

## Architecture Decision Records

ADRs are in `docs/adr/` using dateless format (no dates in filenames or content).
When making significant architectural decisions, create a new ADR following the
existing pattern (Status, Context, Decision, Consequences).

## Claude Code Skills

- **`/new-scp`** — Scaffolds a new SCP: creates JSON policy file, adds Terraform
  resource and attachment in `main.tf`, adds outputs, updates validation scripts.
  Usage: `/new-scp policy-name target-type` (e.g., `/new-scp data-protection ou`).
- **`/ship`** — End-to-end shipping workflow: updates docs (CLAUDE.md, README,
  ADRs, MEMORY), commits, creates PR, monitors CI checks, waits for CodeRabbit
  and Copilot reviews, addresses feedback, and merges when everything passes.
  Usage: `/ship` or `/ship 25` (to resume monitoring an existing PR).

## Security

- Never commit secrets, credentials, private keys, or `.env` files.
- `.gitignore` excludes: `.env`, `.env.local`, `*.pem`, `*.key`, `credentials.json`.
- `detect-secrets` baseline must be updated for false positives:
  `detect-secrets scan --update .secrets.baseline`.
- Use placeholder values in documentation and examples (`YOUR_AWS_ACCOUNT_ID`,
  `YOUR_ORG_ID`, `YOUR_OU_ID`). Terraform backend and infra config may contain
  org-specific values — this rule applies to docs and public-facing content.

## Content Rules

- **Dateless** — No semester names, specific dates, or time-bound links.
- **English only** — All content, code comments, and output in English.
- **Placeholders** — Never hardcode AWS account IDs, credentials, or org IDs.
- **Cross-references** — Directory paths must match actual directory names.
