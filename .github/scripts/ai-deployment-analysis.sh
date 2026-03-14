#!/usr/bin/env bash
set -euo pipefail

# AI-powered post-deployment analysis using Claude via Amazon Bedrock
# Runs after deterministic validation passes
# Required env vars: WORKING_DIRECTORY
# Optional env vars: BEDROCK_MODEL_ID, VALIDATION_LOG

echo "🤖 Running AI deployment analysis..."

BEDROCK_MODEL_ID="${BEDROCK_MODEL_ID:-us.anthropic.claude-sonnet-4-6}"

# Gather all SCP policy content (truncated to 50K total)
POLICIES=""
for policy_file in "$WORKING_DIRECTORY"/policies/*.json; do
  if [ -f "$policy_file" ]; then
    FILENAME=$(basename "$policy_file")
    CONTENT=$(< "$policy_file")
    POLICIES="${POLICIES}
--- ${FILENAME} ---
${CONTENT}
"
  fi
done
POLICIES=$(printf '%s' "$POLICIES" | head -c 50000)

# Gather Terraform plan output if available
PLAN_OUTPUT=""
if [ -f "$WORKING_DIRECTORY/plan.txt" ]; then
  PLAN_OUTPUT=$(head -c 30000 "$WORKING_DIRECTORY/plan.txt")
fi

# Gather validation results from deterministic script
VALIDATION_LOG="${VALIDATION_LOG:-No validation log available}"
VALIDATION_LOG=$(printf '%s' "$VALIDATION_LOG" | head -c 10000)

# Gather live SCP list from AWS
LIVE_SCPS=$(aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[].{Id:Id,Name:Name,Description:Description}' \
  --output json || echo "[]")

# Load accepted findings to avoid re-reporting known issues
ACCEPTED_FINDINGS=""
ACCEPTED_FILE="$WORKING_DIRECTORY/accepted-findings.md"
if [ -f "$ACCEPTED_FILE" ]; then
  ACCEPTED_FINDINGS=$(head -c 20000 "$ACCEPTED_FILE")
fi

# Build the prompt
PROMPT="You are a cloud security expert analyzing an AWS Organizations deployment.

## Deployed SCP Policies

${POLICIES}

## Live SCPs in AWS Organization

${LIVE_SCPS}

## Terraform Plan Output

${PLAN_OUTPUT:-No plan output available}

## Deterministic Validation Results

${VALIDATION_LOG}

## Previously Triaged Findings

The following findings have already been reviewed and triaged.
Do NOT re-report findings listed as Accepted Risk, Won't Fix, or To Fix unless scope changed.
If a finding listed under Fixed is present again, report it as a NEW regression.
Only suppress findings that are still intentionally accepted or triaged.

${ACCEPTED_FINDINGS:-No previously triaged findings.}

## Analysis Instructions

Compare the current SCP policies against the previously triaged findings above.
Report NEW findings and regressions (including reintroduced items from Fixed).
Do not repeat unresolved accepted triage items unless their impact materially changed.

If all findings are already covered in the triaged list, respond with exactly:
No new findings. All previously identified issues have been triaged.

Otherwise, for each NEW finding provide:

### New Findings

For each new finding:
- **Severity**: HIGH / MEDIUM / LOW
- **Category**: security-gap / bug / best-practice / cost-control
- **Description**: What the issue is and why it matters
- **Recommendation**: How to fix it

### Deployment Summary
- What changed in this deployment
- Overall security posture rating (Strong / Adequate / Needs Improvement)
- Whether any new action items were identified

Keep the analysis concise and actionable. Focus on real issues, not theoretical edge cases.
Do not repeat or rephrase findings already in the triaged list."

# Write prompt to temp file for Bedrock CLI (avoids shell escaping issues)
BODY_FILE=$(mktemp)
RESPONSE_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE" "$RESPONSE_FILE"' EXIT

jq -n \
  --arg prompt "$PROMPT" \
  '{
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 4096,
    "messages": [{"role": "user", "content": $prompt}]
  }' > "$BODY_FILE"

# Call Bedrock Claude via AWS CLI (120s timeout for large prompts)
aws bedrock-runtime invoke-model \
  --model-id "$BEDROCK_MODEL_ID" \
  --content-type application/json \
  --accept application/json \
  --cli-read-timeout 120 \
  --body "fileb://$BODY_FILE" \
  "$RESPONSE_FILE"

# Extract the text content
ANALYSIS=$(jq -r '.content[0].text // "Analysis not available"' "$RESPONSE_FILE")

# Save analysis to file for artifact upload
ANALYSIS_FILE="${WORKING_DIRECTORY}/ai-analysis.md"
{
  echo "## 🤖 AI Deployment Analysis"
  echo ""
  echo "$ANALYSIS"
  echo ""
  echo "---"
  echo "*Powered by Claude via Amazon Bedrock ($BEDROCK_MODEL_ID)*"
} > "$ANALYSIS_FILE"

# Post to GitHub Actions step summary
cat "$ANALYSIS_FILE" >> "$GITHUB_STEP_SUMMARY"

echo "✅ AI analysis complete — see step summary and artifact for details"
