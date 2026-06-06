#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

STACK_NAME="${STACK_NAME:-hallastech-static-site}"
REGION="${REGION:-us-east-1}"
CLOUDFRONT_REGION="${CLOUDFRONT_REGION:-us-east-1}"
BUCKET_NAME="${BUCKET_NAME:-}"
DISTRIBUTION_ID="${DISTRIBUTION_ID:-}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required but was not found." >&2
  exit 1
fi

if [[ -z "$BUCKET_NAME" || -z "$DISTRIBUTION_ID" ]]; then
  BUCKET_NAME="$(aws cloudformation describe-stacks \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
    --output text)"

  DISTRIBUTION_ID="$(aws cloudformation describe-stacks \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" \
    --output text)"
fi

if [[ -z "$BUCKET_NAME" || "$BUCKET_NAME" == "None" ]]; then
  echo "Could not determine S3 bucket name from stack outputs." >&2
  exit 1
fi

if [[ -z "$DISTRIBUTION_ID" || "$DISTRIBUTION_ID" == "None" ]]; then
  echo "Could not determine CloudFront distribution ID from stack outputs." >&2
  exit 1
fi

aws s3 sync "$ROOT_DIR" "s3://$BUCKET_NAME" \
  --region "$REGION" \
  --delete \
  --exclude "*" \
  --include "index.html" \
  --include "styles.css" \
  --include "assets/*"

aws cloudfront create-invalidation \
  --region "$CLOUDFRONT_REGION" \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*" \
  --query "Invalidation.[Id,Status]" \
  --output table
