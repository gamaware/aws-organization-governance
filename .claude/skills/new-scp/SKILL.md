---
name: new-scp
description: >-
  Scaffold a new Service Control Policy with JSON policy, Terraform
  resources, outputs, and validation scripts. Use this skill whenever
  the user wants to create a new SCP, add a deny policy, scaffold an
  organization policy, or says something like "add a policy for data
  protection" or "create a new SCP to restrict regions".
disable-model-invocation: true
user-invocable: true
argument-hint: "[policy-name target-type]"
---

# Scaffold a New Service Control Policy

Create a new SCP with all required files following repo conventions.

Argument: `$ARGUMENTS` contains two parts:

- `policy-name`: kebab-case name for the policy (e.g., `data-protection`)
- `target-type`: either `org-root` or `ou` (e.g., `ou`)

## Steps

1. Read `terraform/scps/main.tf` to understand existing SCP patterns.
2. Read `terraform/scps/outputs.tf` to understand output naming patterns.
3. Read an existing policy JSON (e.g., `terraform/scps/policies/dev-restrictions.json`)
   for structure reference.
4. Create `terraform/scps/policies/<policy-name>.json` with:
   - Valid AWS IAM policy structure: `Version` and `Statement` array
   - Statement Sids in PascalCase starting with `Deny`
   - Placeholder deny statement using `Deny` + `"*"` action on a dummy resource
     that the user will replace with actual deny rules
5. Edit `terraform/scps/main.tf` to add:
   - `aws_organizations_policy.<snake_case_name>` resource with:
     - `name` in PascalCase (convert from kebab-case)
     - `content = file("${path.module}/policies/<policy-name>.json")`
   - `aws_organizations_policy_attachment.<snake_case_name>_<target>` resource:
     - If `org-root`: `target_id = data.aws_organizations_organization.current.roots[0].id`
     - If `ou`: `target_id = var.dev_ou_id` (user may need to adjust)
6. Edit `terraform/scps/outputs.tf` to add:
   - `<snake_case_name>_scp_id` output
   - `<snake_case_name>_scp_arn` output
7. Edit `.github/scripts/validate-deployment.sh` to add validation for the new SCP.
8. Edit `.github/scripts/get-terraform-outputs.sh` to include new output keys.
9. Run `terraform fmt terraform/scps/` to format the new code.
10. Run `terraform validate` in `terraform/scps/` to confirm syntax (may fail without
    backend — that is expected locally).

## Naming Conventions

- JSON file: `kebab-case.json` (e.g., `data-protection.json`)
- Terraform resource: `snake_case` (e.g., `data_protection`)
- AWS policy name: `PascalCase` (e.g., `DataProtection`)
- Statement Sids: `PascalCase` starting with `Deny` (e.g., `DenyUnencryptedUploads`)

## After Scaffolding

Tell the user:

1. Edit the policy JSON to add actual deny statements
2. Review the Terraform attachment target
3. Run `pre-commit run --all-files` to validate
4. Create a feature branch and PR
