#!/usr/bin/env bash
set -euo pipefail

# Post-destroy validation — confirms resources are gone from AWS
# Required env vars: EXPECTED_ORG_ID, EXPECTED_DEV_OU, ROOT_ID

fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; }

echo "🔍 Validating destroy..."

# Get root ID from AWS directly (no Terraform state after destroy)
ROOT_ID=$(aws organizations list-roots --query "Roots[0].Id" --output text)
[ "$ROOT_ID" = "" ] && fail "Could not get root ID"

# Check no custom SCPs on Dev OU (only FullAWSAccess should remain)
DEV_POLICIES=$(aws organizations list-policies-for-target \
  --target-id "$EXPECTED_DEV_OU" \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Name!='FullAWSAccess'].Id" \
  --output text)
[ "$DEV_POLICIES" != "" ] && fail "Dev OU still has custom SCPs: $DEV_POLICIES"
pass "No custom SCPs on Dev OU"

# Check no custom SCPs on root (only FullAWSAccess should remain)
ROOT_POLICIES=$(aws organizations list-policies-for-target \
  --target-id "$ROOT_ID" \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Name!='FullAWSAccess'].Id" \
  --output text)
[ "$ROOT_POLICIES" != "" ] && fail "Org root still has custom SCPs: $ROOT_POLICIES"
pass "No custom SCPs on org root"

echo ""
echo "✅ All resources destroyed and verified!"
