# AWS Static Hosting Deployment - `www.hallastech.com`

Current production target:

- Existing S3 website bucket: `www.hallastech.com`
- Bucket region: `us-east-2`
- Existing CloudFront distribution: `E33Q8QG2BXCEVO`
- CloudFront domain: `d6fefspsedmg7.cloudfront.net`
- Existing ACM certificate: `arn:aws:acm:us-east-1:381492120543:certificate/647a1df3-6f9d-4d89-9f58-0d341b3ad4a2`
- DNS provider: Hover

Use this existing target for now. Do not create a new `www.hallastech.com` CloudFront distribution unless you first remove or move the `www.hallastech.com` alternate domain name from the existing distribution.

Optional future architecture:

- Private S3 bucket for static files.
- CloudFront distribution for HTTPS, CDN, and public access.
- CloudFront Origin Access Control so the S3 bucket is not public.
- ACM certificate for `www.hallastech.com`.
- Optional Route 53 `A` and `AAAA` alias records.

Current DNS and CloudFront state:

- `www.hallastech.com` points to `d6fefspsedmg7.cloudfront.net`.
- `hallastech.com` points to `216.40.34.41`.
- `www.hallastech.com` is already configured as an alias on CloudFront distribution `E33Q8QG2BXCEVO`.
- That distribution uses origin `www.hallastech.com.s3-website.us-east-2.amazonaws.com`.

That means the current `www` site already uses CloudFront and an S3 website bucket. The simplest deployment path is to upload new static files to that existing bucket and invalidate that existing distribution.

Important: CloudFront does not allow the same alternate domain name on two distributions at the same time. If the old distribution still has `www.hallastech.com` configured as an alias, creating a new distribution for `www.hallastech.com` may fail with a `CNAMEAlreadyExists` style error.

If that happens, use one of these cutover paths:

- Reuse the existing CloudFront distribution and point it to the new S3 bucket/origin.
- Remove `www.hallastech.com` from the old distribution, wait for CloudFront deployment, then create/update the new distribution.
- Deploy the new stack first with a staging domain, such as `staging.hallastech.com`, verify it, then move the `www` alias during cutover.

## Prerequisites

- AWS CLI installed and configured.
- Permission to write objects to S3 bucket `www.hallastech.com`.
- Permission to create CloudFront invalidations for distribution `E33Q8QG2BXCEVO`.
- For the optional future stack, permission to create S3 buckets, CloudFront distributions, ACM certificates, and Route 53 records.
- For the optional future stack, deploy CloudFormation in `us-east-1`. CloudFront requires ACM viewer certificates in `us-east-1`.

## Upload Site Files To Existing AWS Resources

From this directory:

```bash
./scripts/render_site.py
./scripts/deploy-site.bash
```

This uploads only:

- `index.html`
- `styles.css`
- `assets/*`

It then creates a CloudFront invalidation for `/*`.

## Optional New Infrastructure

Find the hosted zone ID:

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name hallastech.com \
  --query "HostedZones[0].Id" \
  --output text
```

The output looks like `/hostedzone/Z1234567890ABC`. Use only `Z1234567890ABC`.

## Deploy Infrastructure

From the `website` directory:

```bash
HOSTED_ZONE_ID=Z1234567890ABC ./scripts/deploy-infra.sh
```

For a staging deployment:

```bash
DOMAIN_NAME=staging.hallastech.com \
HOSTED_ZONE_ID=Z1234567890ABC \
STACK_NAME=hallastech-static-site-staging \
./scripts/deploy-infra.sh
```

Defaults used by the script:

- Stack name: `hallastech-static-site`
- Region: `us-east-1`
- Domain: `www.hallastech.com`
- CloudFront price class: `PriceClass_100`
- Create ACM certificate: `true`
- Create Route 53 record: `true`

If DNS is not in Route 53, create or validate an ACM certificate manually in `us-east-1`, then deploy with:

```bash
CREATE_CERTIFICATE=false \
CREATE_DNS_RECORD=false \
ACM_CERTIFICATE_ARN=arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID \
./scripts/deploy-infra.sh
```

Then update DNS wherever the domain is hosted by pointing `www.hallastech.com` to the CloudFront domain output from the stack.

## Upload Site Files To New Stack

After the CloudFormation stack is complete:

```bash
BUCKET_NAME="$(aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name hallastech-static-site \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
  --output text)"

DISTRIBUTION_ID="$(aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name hallastech-static-site \
  --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" \
  --output text)"

./scripts/render_site.py
REGION=us-east-1 \
BUCKET_NAME="$BUCKET_NAME" \
DISTRIBUTION_ID="$DISTRIBUTION_ID" \
./scripts/deploy-site.bash
```

This uploads only:

- `index.html`
- `styles.css`
- `assets/*`

It then creates a CloudFront invalidation for `/*`.

## Verify

```bash
aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name hallastech-static-site \
  --query "Stacks[0].Outputs[].[OutputKey,OutputValue]" \
  --output table

dig +short www.hallastech.com
curl -I https://www.hallastech.com
```

CloudFront deployment and DNS propagation can take time. Expect a new distribution to take several minutes before it is fully deployed.

## Updating The Site

Edit `content/site.json`, `templates/index.html.j2`, `styles.css`, or assets, then run:

```bash
./scripts/render_site.py
./scripts/deploy-site.bash
```

For normal production updates, prefer the GitHub Actions flow:

1. Push changes to `dev`.
2. Verify the `Static Site` workflow passes.
3. Merge `dev` into `main`.
4. The `main` workflow deploys to S3/CloudFront.

GitHub Actions AWS setup is documented in `docs/aws/github-actions-oidc.md`.

## Cost Profile

For a small static business site, this should usually be under `$1/month` if traffic is light and CloudFront's free allowance applies. Domain registration renewal is separate.
