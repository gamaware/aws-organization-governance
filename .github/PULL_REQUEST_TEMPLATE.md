# Pull Request

## Description

Brief description of what this PR changes and why.

## Area Affected

- [ ] SCP policies (`terraform/scps/policies/`)
- [ ] Terraform configuration (`terraform/scps/*.tf`)
- [ ] CI/CD workflows (`.github/workflows/`)
- [ ] Composite actions (`.github/actions/`)
- [ ] Scripts (`.github/scripts/`)
- [ ] Documentation (`docs/`)
- [ ] Repository config / pre-commit / linting

## Type of Change

- [ ] Fix — corrects a bug or misconfiguration
- [ ] Improvement — improves existing policy, script, or workflow
- [ ] New content — adds a new SCP, workflow, or documentation

## Checklist

- [ ] Pre-commit hooks pass (`pre-commit run --all-files`)
- [ ] Terraform validates (`terraform validate`)
- [ ] SCP JSON is valid IAM policy syntax
- [ ] Shell scripts pass ShellCheck and shellharden
- [ ] Documentation updated if behavior changed
- [ ] No secrets, credentials, or hardcoded account IDs
