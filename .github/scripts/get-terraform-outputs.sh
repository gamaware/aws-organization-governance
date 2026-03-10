#!/usr/bin/env bash
set -euo pipefail

# Read Terraform outputs and export to GITHUB_OUTPUT
# Must run from the Terraform working directory

outputs=("dev_scp_id" "dev_scp_arn" "org_id:organization_id" "root_id" "sso_scp_id:sso_protection_scp_id" "sso_scp_arn:sso_protection_scp_arn" "dev_tagging_scp_id" "dev_tagging_scp_arn" "region_scp_id:region_restriction_scp_id" "region_scp_arn:region_restriction_scp_arn")

for entry in "${outputs[@]}"; do
  if [[ "$entry" == *":"* ]]; then
    OUTPUT_KEY="${entry%%:*}"
    TF_KEY="${entry##*:}"
  else
    OUTPUT_KEY="$entry"
    TF_KEY="$entry"
  fi
  VALUE=$(terraform output -raw "$TF_KEY" 2>/dev/null || echo "")
  echo "${OUTPUT_KEY}=${VALUE}" >> "$GITHUB_OUTPUT"
done
