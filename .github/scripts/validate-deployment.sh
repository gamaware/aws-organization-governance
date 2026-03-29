#!/usr/bin/env bash
set -euo pipefail

# Post-deployment validation via AWS CLI
# Required env vars: ORG_ID, EXPECTED_ORG_ID, ROOT_ID, EXPECTED_DEV_OU,
#                    DEV_SCP_ID, DEV_SCP_ARN, SSO_SCP_ID, SSO_SCP_ARN,
#                    DEV_TAGGING_SCP_ID, DEV_TAGGING_SCP_ARN,
#                    REGION_SCP_ID, REGION_SCP_ARN,
#                    SECURITY_DEFAULTS_SCP_ID, SECURITY_DEFAULTS_SCP_ARN

fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; }

echo "🔍 Validating deployment..."

# --- Organization ---
[ "$ORG_ID" = "" ] && fail "Could not get organization ID from Terraform output"
[ "$ORG_ID" != "$EXPECTED_ORG_ID" ] && fail "Organization ID mismatch"
pass "Organization verified: ${ORG_ID}"

# --- SCPs enabled ---
SCP_ENABLED=$(aws organizations list-roots \
  --query "Roots[0].PolicyTypes[?Type==\`SERVICE_CONTROL_POLICY\`].Status" \
  --output text)
[ "$SCP_ENABLED" != "ENABLED" ] && fail "SCPs not enabled"
pass "SCPs enabled"

# --- Dev SCP ---
[ "$DEV_SCP_ID" = "" ] && fail "Could not get Dev SCP ID from Terraform output"

SCP_EXISTS=$(aws organizations describe-policy \
  --policy-id "$DEV_SCP_ID" \
  --query 'Policy.PolicySummary.Id' \
  --output text 2>/dev/null || echo "")
[ "$SCP_EXISTS" = "" ] && fail "Dev SCP policy not found in AWS"
pass "Dev SCP policy exists: ${DEV_SCP_ID}"

ATTACHED=$(aws organizations list-policies-for-target \
  --target-id "$EXPECTED_DEV_OU" \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Id==\`${DEV_SCP_ID}\`].Id" \
  --output text)
[ "$ATTACHED" = "" ] && fail "Dev SCP not attached to Dev OU"
pass "Dev SCP attached to Dev OU"

POLICY_CONTENT=$(aws organizations describe-policy \
  --policy-id "$DEV_SCP_ID" \
  --query 'Policy.Content' \
  --output text)

echo "$POLICY_CONTENT" | grep -q "ec2:InstanceType" || fail "Instance type restriction not found"
pass "Instance type restriction validated"
echo "$POLICY_CONTENT" | grep -q "aws:PrincipalArn" || fail "Root user restriction not found"
pass "Root user restriction validated"

# --- SSO Protection SCP ---
[ "$SSO_SCP_ID" = "" ] && fail "Could not get SSO SCP ID from Terraform output"

SSO_EXISTS=$(aws organizations describe-policy \
  --policy-id "$SSO_SCP_ID" \
  --query 'Policy.PolicySummary.Id' \
  --output text 2>/dev/null || echo "")
[ "$SSO_EXISTS" = "" ] && fail "SSO Protection SCP not found in AWS"
pass "SSO Protection SCP exists: ${SSO_SCP_ID}"

SSO_ATTACHED=$(aws organizations list-policies-for-target \
  --target-id "$ROOT_ID" \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Id==\`${SSO_SCP_ID}\`].Id" \
  --output text)
[ "$SSO_ATTACHED" = "" ] && fail "SSO Protection SCP not attached to org root"
pass "SSO Protection SCP attached to org root"

SSO_CONTENT=$(aws organizations describe-policy \
  --policy-id "$SSO_SCP_ID" \
  --query 'Policy.Content' \
  --output text)

echo "$SSO_CONTENT" | grep -q "organizations:DisableAWSServiceAccess" \
  || fail "DisableAWSServiceAccess deny not found"
pass "DisableAWSServiceAccess deny validated"
echo "$SSO_CONTENT" | grep -q "sso.amazonaws.com" \
  || fail "SSO service principal condition not found"
pass "SSO service principal condition validated"

# --- Dev Tagging and Abuse Prevention SCP ---
[ "$DEV_TAGGING_SCP_ID" = "" ] && fail "Could not get Tagging SCP ID"

TAGGING_EXISTS=$(aws organizations describe-policy \
  --policy-id "$DEV_TAGGING_SCP_ID" \
  --query 'Policy.PolicySummary.Id' \
  --output text 2>/dev/null || echo "")
[ "$TAGGING_EXISTS" = "" ] && fail "Tagging SCP not found in AWS"
pass "Tagging SCP exists: ${DEV_TAGGING_SCP_ID}"

TAGGING_ATTACHED=$(aws organizations list-policies-for-target \
  --target-id "$EXPECTED_DEV_OU" \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Id==\`${DEV_TAGGING_SCP_ID}\`].Id" \
  --output text)
[ "$TAGGING_ATTACHED" = "" ] && fail "Tagging SCP not attached to Dev OU"
pass "Tagging SCP attached to Dev OU"

TAGGING_CONTENT=$(aws organizations describe-policy \
  --policy-id "$DEV_TAGGING_SCP_ID" \
  --query 'Policy.Content' \
  --output text)

echo "$TAGGING_CONTENT" | grep -q "aws:RequestTag/Team" \
  || fail "Team tag enforcement not found"
pass "Team tag enforcement validated"
echo "$TAGGING_CONTENT" | grep -q "iteso.mx" \
  || fail "ITESO email tag enforcement not found"
pass "ITESO email tag enforcement validated"

# --- Region Restriction SCP ---
[ "$REGION_SCP_ID" = "" ] && fail "Could not get Region Restriction SCP ID"

REGION_EXISTS=$(aws organizations describe-policy \
  --policy-id "$REGION_SCP_ID" \
  --query 'Policy.PolicySummary.Id' \
  --output text 2>/dev/null || echo "")
[ "$REGION_EXISTS" = "" ] && fail "Region Restriction SCP not found in AWS"
pass "Region Restriction SCP exists: ${REGION_SCP_ID}"

REGION_ATTACHED=$(aws organizations list-policies-for-target \
  --target-id "$ROOT_ID" \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Id==\`${REGION_SCP_ID}\`].Id" \
  --output text)
[ "$REGION_ATTACHED" = "" ] && fail "Region Restriction SCP not attached to org root"
pass "Region Restriction SCP attached to org root"

REGION_CONTENT=$(aws organizations describe-policy \
  --policy-id "$REGION_SCP_ID" \
  --query 'Policy.Content' \
  --output text)

echo "$REGION_CONTENT" | grep -q "aws:RequestedRegion" \
  || fail "Region condition not found in Region Restriction SCP"
pass "Region restriction condition validated"

# --- Security Defaults SCP ---
[ "$SECURITY_DEFAULTS_SCP_ID" = "" ] && fail "Could not get Security Defaults SCP ID"

SEC_EXISTS=$(aws organizations describe-policy \
  --policy-id "$SECURITY_DEFAULTS_SCP_ID" \
  --query 'Policy.PolicySummary.Id' \
  --output text 2>/dev/null || echo "")
[ "$SEC_EXISTS" = "" ] && fail "Security Defaults SCP not found in AWS"
pass "Security Defaults SCP exists: ${SECURITY_DEFAULTS_SCP_ID}"

SEC_ATTACHED=$(aws organizations list-policies-for-target \
  --target-id "$EXPECTED_DEV_OU" \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Id==\`${SECURITY_DEFAULTS_SCP_ID}\`].Id" \
  --output text)
[ "$SEC_ATTACHED" = "" ] && fail "Security Defaults SCP not attached to Dev OU"
pass "Security Defaults SCP attached to Dev OU"

SEC_CONTENT=$(aws organizations describe-policy \
  --policy-id "$SECURITY_DEFAULTS_SCP_ID" \
  --query 'Policy.Content' \
  --output text)

echo "$SEC_CONTENT" | grep -q "DenyDisableEBSEncryption" \
  || fail "EBS encryption deny not found"
pass "EBS encryption deny validated"
echo "$SEC_CONTENT" | grep -q "DenyIMDSv1" \
  || fail "IMDSv1 deny not found"
pass "IMDSv1 deny validated"
echo "$SEC_CONTENT" | grep -q "DenyDeleteS3PublicAccessBlock" \
  || fail "S3 public access block deny not found"
pass "S3 public access block deny validated"

echo ""
echo "✅ All validations passed!"
echo "📊 Deployment Summary:"
echo "  - Organization: ${ORG_ID}"
echo "  - Root: ${ROOT_ID}"
echo "  - Dev OU: ${EXPECTED_DEV_OU}"
echo "  - Dev SCP: ${DEV_SCP_ID} (${DEV_SCP_ARN})"
echo "  - Tagging SCP: ${DEV_TAGGING_SCP_ID} (${DEV_TAGGING_SCP_ARN})"
echo "  - SSO Protection SCP: ${SSO_SCP_ID} (${SSO_SCP_ARN})"
echo "  - Region Restriction SCP: ${REGION_SCP_ID} (${REGION_SCP_ARN})"
echo "  - Security Defaults SCP: ${SECURITY_DEFAULTS_SCP_ID} (${SECURITY_DEFAULTS_SCP_ARN})"
echo "  - Status: Deployed and validated"
