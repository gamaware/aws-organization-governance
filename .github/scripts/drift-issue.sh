#!/usr/bin/env bash
set -euo pipefail

# Create or update a GitHub issue when drift is detected
# Requires: WORKING_DIRECTORY, GITHUB_REPOSITORY, GITHUB_RUN_ID,
#           GITHUB_RUN_NUMBER, GITHUB_SERVER_URL

PLAN_FILE="${WORKING_DIRECTORY}/plan.txt"
REPO="$GITHUB_REPOSITORY"
RUN_URL="${GITHUB_SERVER_URL}/${REPO}/actions/runs/${GITHUB_RUN_ID}"

BODY="## ⚠️ Configuration Drift Detected

**Run:** [#${GITHUB_RUN_NUMBER}](${RUN_URL})
**Detected:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Module:** \`${WORKING_DIRECTORY}\`

<details>
<summary>Drift Details</summary>

\`\`\`terraform
$(head -c 60000 "$PLAN_FILE")
\`\`\`

</details>

### Next Steps
1. Review drift details above
2. Create PR to remediate if needed
3. Close issue once resolved"

# Find existing open drift issue
EXISTING_ISSUE=$(gh issue list \
  --repo "$REPO" \
  --label "drift-detection" \
  --state open \
  --json number,title \
  --jq '.[] | select(.title | contains("Configuration Drift Detected")) | .number' \
  | head -1)

if [ "$EXISTING_ISSUE" != "" ]; then
  echo "Updating existing issue #${EXISTING_ISSUE}"
  gh issue comment "$EXISTING_ISSUE" \
    --repo "$REPO" \
    --body "### New Drift Detected

${BODY}"
else
  echo "Creating new drift issue"
  gh issue create \
    --repo "$REPO" \
    --title "⚠️ Configuration Drift Detected" \
    --body "$BODY" \
    --label "drift-detection" \
    --label "infrastructure"
fi
