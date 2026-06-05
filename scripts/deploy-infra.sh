#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

STACK_NAME="${STACK_NAME:-hallastech-static-site}"
REGION="${REGION:-us-east-1}"
DOMAIN_NAME="${DOMAIN_NAME:-www.hallastech.com}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
CREATE_CERTIFICATE="${CREATE_CERTIFICATE:-true}"
CREATE_DNS_RECORD="${CREATE_DNS_RECORD:-true}"
ACM_CERTIFICATE_ARN="${ACM_CERTIFICATE_ARN:-}"
PRICE_CLASS="${PRICE_CLASS:-PriceClass_100}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required but was not found." >&2
  exit 1
fi

aws cloudformation deploy \
  --region "$REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$ROOT_DIR/aws/static-site.yaml" \
  --parameter-overrides \
    DomainName="$DOMAIN_NAME" \
    HostedZoneId="$HOSTED_ZONE_ID" \
    CreateCertificate="$CREATE_CERTIFICATE" \
    AcmCertificateArn="$ACM_CERTIFICATE_ARN" \
    CreateDnsRecord="$CREATE_DNS_RECORD" \
    PriceClass="$PRICE_CLASS"

aws cloudformation describe-stacks \
  --region "$REGION" \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[].[OutputKey,OutputValue]" \
  --output table
