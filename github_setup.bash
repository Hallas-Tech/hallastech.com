#!/usr/bin/env bash
set -euo pipefail

ROLE_NAME="${ROLE_NAME:-hallastech-github-actions-deploy}"
POLICY_NAME="${POLICY_NAME:-hallastech-static-site-deploy}"
REPO="${REPO:-Hallas-Tech/hallastech.com}"
BRANCH="${BRANCH:-main}"
GITHUB_ENVIRONMENT="${GITHUB_ENVIRONMENT:-production}"
BUCKET_NAME="${BUCKET_NAME:-www.hallastech.com}"
DISTRIBUTION_ID="${DISTRIBUTION_ID:-E33Q8QG2BXCEVO}"
OIDC_PROVIDER_HOST="${OIDC_PROVIDER_HOST:-token.actions.githubusercontent.com}"
OIDC_AUDIENCE="${OIDC_AUDIENCE:-sts.amazonaws.com}"
GITHUB_SECRET_NAME="${GITHUB_SECRET_NAME:-AWS_ROLE_TO_ASSUME}"
SET_GITHUB_SECRET="${SET_GITHUB_SECRET:-false}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_command aws
require_command python3

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER_HOST}"
if [[ -n "$GITHUB_ENVIRONMENT" ]]; then
  ROLE_SUBJECT="repo:${REPO}:environment:${GITHUB_ENVIRONMENT}"
else
  ROLE_SUBJECT="repo:${REPO}:ref:refs/heads/${BRANCH}"
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

TRUST_POLICY="${WORK_DIR}/github-actions-trust.json"
DEPLOY_POLICY="${WORK_DIR}/hallastech-deploy-policy.json"

echo "AWS account: ${ACCOUNT_ID}"
echo "GitHub repo: ${REPO}"
echo "Deploy branch: ${BRANCH}"
echo "GitHub environment: ${GITHUB_ENVIRONMENT:-none}"
echo "IAM role: ${ROLE_NAME}"
echo "S3 bucket: ${BUCKET_NAME}"
echo "CloudFront distribution: ${DISTRIBUTION_ID}"
echo

echo "Checking GitHub OIDC provider..."
if aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" >/dev/null 2>&1; then
  echo "OIDC provider exists: ${OIDC_PROVIDER_ARN}"

  HAS_AUDIENCE="$(aws iam get-open-id-connect-provider \
    --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" \
    --query "contains(ClientIDList, '${OIDC_AUDIENCE}')" \
    --output text)"

  if [[ "$HAS_AUDIENCE" != "True" ]]; then
    echo "Adding OIDC audience: ${OIDC_AUDIENCE}"
    aws iam add-client-id-to-open-id-connect-provider \
      --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" \
      --client-id "$OIDC_AUDIENCE"
  fi
else
  echo "Creating OIDC provider: ${OIDC_PROVIDER_ARN}"
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_PROVIDER_HOST}" \
    --client-id-list "$OIDC_AUDIENCE" >/dev/null
fi

cat >"$TRUST_POLICY" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER_HOST}:aud": "${OIDC_AUDIENCE}",
          "${OIDC_PROVIDER_HOST}:sub": "${ROLE_SUBJECT}"
        }
      }
    }
  ]
}
EOF

cat >"$DEPLOY_POLICY" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListStaticSiteBucket",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    },
    {
      "Sid": "WriteStaticSiteObjects",
      "Effect": "Allow",
      "Action": [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    },
    {
      "Sid": "InvalidateCloudFront",
      "Effect": "Allow",
      "Action": "cloudfront:CreateInvalidation",
      "Resource": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DISTRIBUTION_ID}"
    }
  ]
}
EOF

python3 -m json.tool "$TRUST_POLICY" >/dev/null
python3 -m json.tool "$DEPLOY_POLICY" >/dev/null

echo "Creating or updating IAM role trust policy..."
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document "file://${TRUST_POLICY}" >/dev/null
else
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${TRUST_POLICY}" >/dev/null
fi

echo "Attaching inline deploy policy..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "file://${DEPLOY_POLICY}"

ACTUAL_ROLE_ARN="$(aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query "Role.Arn" \
  --output text)"

echo
echo "AWS setup complete."
echo
echo "Add this GitHub Actions secret:"
echo
echo "  ${GITHUB_SECRET_NAME}=${ACTUAL_ROLE_ARN}"
echo
echo "GitHub UI path:"
echo "  Hallas-Tech/hallastech.com -> Settings -> Secrets and variables -> Actions -> New repository secret"
echo

if [[ "$SET_GITHUB_SECRET" == "true" ]]; then
  require_command gh
  echo "Setting GitHub Actions secret with gh..."
  gh secret set "$GITHUB_SECRET_NAME" --repo "$REPO" --body "$ACTUAL_ROLE_ARN"
  echo
elif command -v gh >/dev/null 2>&1; then
  echo "Optional: if GitHub CLI is authenticated, set the secret with:"
  echo
  echo "  gh secret set ${GITHUB_SECRET_NAME} --repo ${REPO} --body \"${ACTUAL_ROLE_ARN}\""
  echo
fi

echo "After the secret exists, commit and push .github/workflows/static-site.yml to dev."
