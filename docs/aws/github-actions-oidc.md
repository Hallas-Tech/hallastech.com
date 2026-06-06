# GitHub Actions AWS OIDC Setup

The production deploy workflow uses GitHub OIDC to assume an AWS IAM role. Do not store long-lived AWS access keys in GitHub.

Workflow file:

```text
.github/workflows/static-site.yml
```

Deploy behavior:

- `dev`: render and validate only.
- `main`: render, sync S3, and invalidate CloudFront.
- Merging `dev` into `main` triggers production deploy after the push to `main`.

## 1. Create Or Confirm The GitHub OIDC Provider

In AWS IAM, create an OIDC identity provider if one does not already exist:

```text
Provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
```

## 2. Create The Deploy Role

Suggested role name:

```text
hallastech-github-actions-deploy
```

Trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:Hallas-Tech/hallastech.com:environment:production"
        }
      }
    }
  ]
}
```

Replace `ACCOUNT_ID` with your AWS account ID.

This trust policy matches the deploy job's GitHub environment, `production`. The workflow itself is still restricted to `main` by:

```yaml
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

If you remove the `environment: production` block from the workflow, change the trust policy subject back to `repo:Hallas-Tech/hallastech.com:ref:refs/heads/main`.

## 3. Attach Permissions

Use this policy for the existing AWS resources:

- S3 bucket: `www.hallastech.com`
- CloudFront distribution: `E33Q8QG2BXCEVO`

```json
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
      "Resource": "arn:aws:s3:::www.hallastech.com"
    },
    {
      "Sid": "WriteStaticSiteObjects",
      "Effect": "Allow",
      "Action": [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::www.hallastech.com/*"
    },
    {
      "Sid": "InvalidateCloudFront",
      "Effect": "Allow",
      "Action": "cloudfront:CreateInvalidation",
      "Resource": "arn:aws:cloudfront::381492120543:distribution/E33Q8QG2BXCEVO"
    }
  ]
}
```

If you create a new AWS account or move the distribution, update the CloudFront resource ARN.

## 4. Add GitHub Secret

In GitHub:

```text
Repository -> Settings -> Secrets and variables -> Actions -> New repository secret
```

Create:

```text
AWS_ROLE_TO_ASSUME=arn:aws:iam::ACCOUNT_ID:role/hallastech-github-actions-deploy
```

## 5. Deploy Flow

1. Keep normal changes on `dev`.
2. Confirm the `Static Site` workflow passes on `dev`.
3. Merge `dev` into `main`.
4. The `main` push triggers production deploy to S3/CloudFront.

## Notes

- The workflow currently deploys to S3 bucket `www.hallastech.com` in `us-east-2`.
- The workflow invalidates CloudFront distribution `E33Q8QG2BXCEVO`.
- CloudFront invalidation can take a few minutes after the workflow finishes.
