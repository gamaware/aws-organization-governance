# Contributing

Thank you for your interest in improving this project.

## Who Can Contribute

- Infrastructure engineers who spot issues in SCP policies or Terraform code
- Security professionals who identify governance gaps or misconfigurations
- Anyone who finds a bug in a script or workflow

## How to Report an Issue

Open a [GitHub Issue](../../issues) describing:

- Which SCP, workflow, or script is affected
- What is wrong or misconfigured
- What the correct behavior should be

## How to Submit a Fix

1. Fork the repository
2. Create a branch: `git checkout -b fix/short-description`
3. Make your changes
4. Run pre-commit hooks: `pre-commit run --all-files`
5. Open a Pull Request against `main` with a clear description of what you changed and why

## Code Guidelines

- Terraform must pass `terraform fmt`, `terraform validate`, TFLint, and Checkov
- Shell scripts must pass ShellCheck and shellharden
- Markdown must pass markdownlint (config in `.markdownlint.yaml`)
- SCP JSON must be valid AWS IAM policy syntax
- Commits must follow [Conventional Commits](https://www.conventionalcommits.org/)

## Questions

Reach out via email: <alejandrogarcia@iteso.mx>
