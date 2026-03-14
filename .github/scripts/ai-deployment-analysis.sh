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

## Analysis Instructions

Analyze the deployment and provide a structured report:

### 1. Security Posture Assessment
- Are there any permission escalation paths the deny statements miss?
- Are the NotAction exemptions in the region restriction SCP complete for global services?
- Could any SCP be bypassed via service-linked roles or other mechanisms?

### 2. SCP Conflict Analysis
- Are there any conflicting deny patterns between org-root and OU-level SCPs?
- Does the union-deny model create any unintended blocks?
- Are there any gaps where actions should be denied but are not?

### 3. Best Practices Check
- Are SCP Sids descriptive and following naming conventions?
- Are conditions properly scoped (StringEquals vs StringLike)?
- Are there any overly broad or overly narrow deny statements?

### 4. Recommendations
- Any missing deny statements for common security threats?
- Any global services missing from the NotAction region restriction list?
- Any cost control gaps in the Dev OU restrictions?

### 5. Deployment Summary
- What changed in this deployment
- Overall security posture rating (Strong/Adequate/Needs Improvement)
- Top 3 action items if any

Keep the analysis concise and actionable. Focus on real issues, not theoretical edge cases."

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

# Post to GitHub Actions step summary
{
  echo "## 🤖 AI Deployment Analysis"
  echo ""
  echo "$ANALYSIS"
  echo ""
  echo "---"
  echo "*Powered by Claude via Amazon Bedrock (${BEDROCK_MODEL_ID})*"
} >> "$GITHUB_STEP_SUMMARY"

echo "✅ AI analysis complete — see step summary for details"
