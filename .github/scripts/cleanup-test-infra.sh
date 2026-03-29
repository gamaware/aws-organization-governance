#!/usr/bin/env bash
set -euo pipefail

# Creates tagged test resources to validate cleanup automation.
# All resources follow SCP tag requirements (Team + Name).
# Usage: ./cleanup-test-infra.sh [create|destroy] [--profile PROFILE]

ACTION="${1:-create}"
PROFILE="${3:-dev}"
TEAM="team-1"
NAME="test@iteso.mx"
REGION="us-east-1"

pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; exit 1; }
info() { echo "ℹ️  $1"; }

if [ "$ACTION" = "create" ]; then
  echo "🔧 Creating test infrastructure (Team=$TEAM)..."

  # DynamoDB table
  info "Creating DynamoDB table..."
  aws dynamodb create-table \
    --table-name "cleanup-test-table" \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Team,Value="$TEAM" Key=Name,Value="$NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --no-cli-auto-prompt \
    --output text > /dev/null 2>&1 || true
  pass "DynamoDB table created"

  # SQS queue
  info "Creating SQS queue..."
  QUEUE_URL=$(aws sqs create-queue \
    --queue-name "cleanup-test-queue" \
    --tags "Team=$TEAM,Name=$NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --no-cli-auto-prompt \
    --query 'QueueUrl' --output text 2>/dev/null || echo "exists")
  pass "SQS queue created: $QUEUE_URL"

  # SNS topic
  info "Creating SNS topic..."
  aws sns create-topic \
    --name "cleanup-test-topic" \
    --tags Key=Team,Value="$TEAM" Key=Name,Value="$NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --no-cli-auto-prompt \
    --output text > /dev/null 2>&1 || true
  pass "SNS topic created"

  # S3 bucket
  BUCKET_NAME="cleanup-test-${TEAM}-$(date +%s)"
  info "Creating S3 bucket: $BUCKET_NAME..."
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --no-cli-auto-prompt \
    --output text > /dev/null 2>&1
  aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging "TagSet=[{Key=Team,Value=$TEAM},{Key=Name,Value=$NAME}]" \
    --profile "$PROFILE" \
    --no-cli-auto-prompt 2>&1
  pass "S3 bucket created and tagged: $BUCKET_NAME"

  echo ""
  echo "✅ Test infrastructure created. Run cleanup to verify deletion."
  echo "   Team: $TEAM"
  echo "   Resources: DynamoDB table, SQS queue, SNS topic, S3 bucket"

elif [ "$ACTION" = "destroy" ]; then
  echo "🗑️  Destroying test infrastructure..."

  aws dynamodb delete-table \
    --table-name "cleanup-test-table" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --no-cli-auto-prompt 2>/dev/null || true
  pass "DynamoDB table deleted"

  QUEUE_URL=$(aws sqs get-queue-url \
    --queue-name "cleanup-test-queue" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --no-cli-auto-prompt \
    --query 'QueueUrl' --output text 2>/dev/null || echo "")
  if [ "$QUEUE_URL" != "" ] && [ "$QUEUE_URL" != "None" ]; then
    aws sqs delete-queue --queue-url "$QUEUE_URL" \
      --profile "$PROFILE" --region "$REGION" --no-cli-auto-prompt 2>/dev/null || true
  fi
  pass "SQS queue deleted"

  ACCOUNT_ID=$(aws sts get-caller-identity \
    --profile "$PROFILE" \
    --query 'Account' --output text 2>/dev/null)
  aws sns delete-topic \
    --topic-arn "arn:aws:sns:${REGION}:${ACCOUNT_ID}:cleanup-test-topic" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --no-cli-auto-prompt 2>/dev/null || true
  pass "SNS topic deleted"

  echo "⚠️  S3 bucket must be deleted manually (name is dynamic)."
  echo "✅ Test infrastructure destroyed."
else
  echo "Usage: $0 [create|destroy] [--profile PROFILE]"
  exit 1
fi
