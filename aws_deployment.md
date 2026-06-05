# AWS Static Hosting Deployment - `www.hallastech.com`

Target architecture:

- Private S3 bucket for static files.
- CloudFront distribution for HTTPS, CDN, and public access.
- CloudFront Origin Access Control so the S3 bucket is not public.
- ACM certificate for `www.hallastech.com`.
- Optional Route 53 `A` and `AAAA` alias records.

Current DNS lookup from this workspace:

- `www.hallastech.com` points to `d6fefspsedmg7.cloudfront.net`.
- `hallastech.com` points to `216.40.34.41`.

That means the old `www` site likely already uses CloudFront. Do not delete the old distribution or DNS record until the new CloudFront distribution is created, files are uploaded, and the new distribution is verified.

Important: CloudFront does not allow the same alternate domain name on two distributions at the same time. If the old distribution still has `www.hallastech.com` configured as an alias, creating a new distribution for `www.hallastech.com` may fail with a `CNAMEAlreadyExists` style error.

If that happens, use one of these cutover paths:

- Reuse the existing CloudFront distribution and point it to the new S3 bucket/origin.
- Remove `www.hallastech.com` from the old distribution, wait for CloudFront deployment, then create/update the new distribution.
- Deploy the new stack first with a staging domain, such as `staging.hallastech.com`, verify it, then move the `www` alias during cutover.

## Prerequisites

- AWS CLI installed and configured.
- Permission to create S3 buckets, CloudFront distributions, ACM certificates, and Route 53 records.
- Route 53 hosted zone ID for `hallastech.com`, if DNS is managed in Route 53.
- Deploy the CloudFormation stack in `us-east-1`. CloudFront requires ACM viewer certificates in `us-east-1`.

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

## Upload Site Files

After the CloudFormation stack is complete:

```bash
./scripts/render_site.py
./scripts/sync-site.sh
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
./scripts/sync-site.sh
```

## Cost Profile

For a small static business site, this should usually be under `$1/month` if traffic is light and CloudFront's free allowance applies. Domain registration renewal is separate.
