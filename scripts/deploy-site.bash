#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REGION="${REGION:-us-east-2}"
CLOUDFRONT_REGION="${CLOUDFRONT_REGION:-us-east-1}"
BUCKET_NAME="${BUCKET_NAME:-www.hallastech.com}"
DISTRIBUTION_ID="${DISTRIBUTION_ID:-E33Q8QG2BXCEVO}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required but was not found." >&2
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
