#!/usr/bin/env bash
set -euo pipefail

# Wait for Quality Checks and Security Scanning workflows to complete
# Required env vars: GITHUB_SHA, GITHUB_REPOSITORY, GH_TOKEN

SHA="$GITHUB_SHA"
MAX_ATTEMPTS=30
SLEEP_INTERVAL=10

echo "Waiting for Quality Checks and Security Scanning to complete for $SHA..."

i=0
while [ "$i" -lt "$MAX_ATTEMPTS" ]; do
  i=$((i + 1))
  QC_STATUS=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs?head_sha=$SHA&event=push" \
    --jq '.workflow_runs[] | select(.name == "Quality Checks") | .conclusion' 2>/dev/null || echo "pending")
  SEC_STATUS=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs?head_sha=$SHA&event=push" \
    --jq '.workflow_runs[] | select(.name == "Security Scanning") | .conclusion' 2>/dev/null || echo "pending")

  echo "Attempt $i/$MAX_ATTEMPTS — Quality Checks: $QC_STATUS | Security Scanning: $SEC_STATUS"

  if [ "$QC_STATUS" = "success" ] && [ "$SEC_STATUS" = "success" ]; then
    echo "Both workflows passed!"

    {
      echo "## Quality and Security Gate"
      echo ""
      echo "- Quality Checks: Passed"
      echo "- Security Scanning: Passed"
      echo "- Status: Terraform plan/apply authorized"
    } >> "$GITHUB_STEP_SUMMARY"

    exit 0
  fi

  if [ "$QC_STATUS" = "failure" ] || [ "$SEC_STATUS" = "failure" ]; then
    echo "BLOCKED: Quality Checks ($QC_STATUS) or Security Scanning ($SEC_STATUS) failed."
    echo "Terraform plan/apply will not proceed."

    {
      echo "## Quality and Security Gate"
      echo ""
      echo "- Quality Checks: $QC_STATUS"
      echo "- Security Scanning: $SEC_STATUS"
      echo "- Status: BLOCKED — Terraform plan/apply will not proceed"
    } >> "$GITHUB_STEP_SUMMARY"

    exit 1
  fi

  sleep "$SLEEP_INTERVAL"
done

echo "Timed out waiting for workflows after $((MAX_ATTEMPTS * SLEEP_INTERVAL)) seconds."

{
  echo "## Quality and Security Gate"
  echo ""
  echo "- Quality Checks: $QC_STATUS"
  echo "- Security Scanning: $SEC_STATUS"
  echo "- Status: TIMED OUT — Terraform plan/apply blocked"
} >> "$GITHUB_STEP_SUMMARY"

exit 1
