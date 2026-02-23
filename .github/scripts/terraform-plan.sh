#!/usr/bin/env bash
set -euo pipefail

# Terraform plan with detailed exit codes and step summary

set +e
terraform plan -detailed-exitcode -no-color -out=tfplan 2>&1 | tee plan.txt
EXIT_CODE=$?
set -e

echo "exit_code=$EXIT_CODE" >> "$GITHUB_OUTPUT"

# Generate human-friendly step summary
{
  echo "## Terraform Plan Summary"
  echo ""

  if [ "$EXIT_CODE" -eq 0 ]; then
    echo "✅ **No changes.** Infrastructure is up to date."
  elif [ "$EXIT_CODE" -eq 2 ]; then
    # Count resources
    ADD=$(grep -c "will be created" plan.txt || true)
    CHANGE=$(grep -c "will be updated" plan.txt || true)
    DESTROY=$(grep -c "will be destroyed" plan.txt || true)

    echo "| Action | Count |"
    echo "| ------ | ----- |"
    echo "| ➕ Create | $ADD |"
    echo "| 🔄 Update | $CHANGE |"
    echo "| ❌ Destroy | $DESTROY |"
    echo ""
    echo "### Resources"
    echo ""
    echo "| Action | Resource |"
    echo "| ------ | -------- |"
    grep -E "will be (created|updated|destroyed)" plan.txt \
      | sed 's/^.*# //' \
      | while IFS= read -r line; do
          if echo "$line" | grep -q "created"; then
            echo "| ➕ Create | \`$(echo "$line" | sed 's/ will be created//')\` |"
          elif echo "$line" | grep -q "updated"; then
            echo "| 🔄 Update | \`$(echo "$line" | sed 's/ will be updated in-place//')\` |"
          elif echo "$line" | grep -q "destroyed"; then
            echo "| ❌ Destroy | \`$(echo "$line" | sed 's/ will be destroyed//')\` |"
          fi
        done
  else
    echo "❌ **Plan failed.** Check the logs for details."
  fi
} >> "$GITHUB_STEP_SUMMARY"

if [ "$EXIT_CODE" -eq 1 ]; then
  exit 1
fi
