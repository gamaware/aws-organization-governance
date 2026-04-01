#!/usr/bin/env bash
set -euo pipefail

# Wait for CI Checks workflow to complete
# Required env vars: GITHUB_SHA, GITHUB_REPOSITORY, GH_TOKEN

SHA="$GITHUB_SHA"
MAX_ATTEMPTS=30
SLEEP_INTERVAL=10

echo "Waiting for CI Checks to complete for $SHA..."

i=0
while [ "$i" -lt "$MAX_ATTEMPTS" ]; do
  i=$((i + 1))
  CI_STATUS=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs?head_sha=$SHA&event=push" \
    --jq '.workflow_runs[] | select(.name == "CI Checks") | .conclusion' 2>/dev/null || echo "pending")

  echo "Attempt $i/$MAX_ATTEMPTS — CI Checks: $CI_STATUS"

  if [ "$CI_STATUS" = "success" ]; then
    echo "CI Checks passed!"

    {
      echo "## Quality and Security Gate"
      echo ""
      echo "- CI Checks: Passed"
      echo "- Status: Terraform plan/apply authorized"
    } >> "$GITHUB_STEP_SUMMARY"

    exit 0
  fi

  if [ "$CI_STATUS" = "failure" ]; then
    echo "BLOCKED: CI Checks failed."
    echo "Terraform plan/apply will not proceed."

    {
      echo "## Quality and Security Gate"
      echo ""
      echo "- CI Checks: Failed"
      echo "- Status: BLOCKED — Terraform plan/apply will not proceed"
    } >> "$GITHUB_STEP_SUMMARY"

    exit 1
  fi

  sleep "$SLEEP_INTERVAL"
done

echo "Timed out waiting for CI Checks after $((MAX_ATTEMPTS * SLEEP_INTERVAL)) seconds."

{
  echo "## Quality and Security Gate"
  echo ""
  echo "- CI Checks: $CI_STATUS"
  echo "- Status: TIMED OUT — Terraform plan/apply blocked"
} >> "$GITHUB_STEP_SUMMARY"

exit 1
