#!/usr/bin/env bash
set -euo pipefail

# Terraform plan for drift detection
# Exit codes: 0 = no changes, 1 = error, 2 = changes detected

set +e
terraform plan -detailed-exitcode -no-color -out=drift.tfplan | tee plan.txt
EXIT_CODE=$?
set -e

echo "exit_code=${EXIT_CODE}" >> "$GITHUB_OUTPUT"

if [ "$EXIT_CODE" -eq 1 ]; then
  exit 1
fi
