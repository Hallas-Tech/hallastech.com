# Hallas Tech Website

Static SDVOSB business website for `www.hallastech.com`.

The site is generated with Jinja2:

- Edit content in `content/site.json`.
- Edit page structure in `templates/index.html.j2`.
- Run `scripts/render_site.py` to generate `index.html`.
- Serve the generated static files with Podman or upload them to S3.

The only runtime JavaScript closes the mobile navigation menu after a link is selected.

## Setup

Jinja2 is required for rendering:

```bash
python3 -m pip install -r requirements.txt
```

## Render

From this directory:

```bash
./scripts/render_site.py
```

This writes:

```text
index.html
```

## Preview Locally With Podman

Render first, then run a stock Caddy container with a bind mount:

```bash
./scripts/render_site.py

podman run --rm --name hallastech-local \
  -p 8080:80 \
  --security-opt label=disable \
  -v "$PWD":/srv:ro \
  docker.io/library/caddy:2-alpine \
  caddy file-server --root /srv --listen :80
```

Then open:

```text
http://localhost:8080
```

After edits, rerun `./scripts/render_site.py` and refresh the browser.

## Deploy To AWS

Read [aws_deployment.md](aws_deployment.md).

This repo is currently set up to reuse the existing AWS site:

- S3 bucket: `www.hallastech.com`
- S3 region: `us-east-2`
- CloudFront distribution: `E33Q8QG2BXCEVO`

Short version from this directory:

```bash
./scripts/render_site.py
REGION=us-east-2 \
BUCKET_NAME=www.hallastech.com \
DISTRIBUTION_ID=E33Q8QG2BXCEVO \
./scripts/sync-site.sh
```

The optional new-infrastructure stack is defined in `aws/static-site.yaml`, but production deploys currently use the existing S3 bucket and CloudFront distribution.

## Branch Flow

Use `dev` as the staging branch.

- Push normal website edits to `dev`.
- The GitHub Actions workflow renders and validates the static site on `dev`.
- Merge `dev` into `main` when ready.
- A push to `main` deploys the generated site to S3/CloudFront and creates a CloudFront invalidation.

See [docs/aws/github-actions-oidc.md](docs/aws/github-actions-oidc.md) for the AWS role and GitHub secret setup.

## Update The Live Site

After editing `content/site.json`, `templates/index.html.j2`, `styles.css`, or files under `assets/`:

```bash
./scripts/render_site.py
REGION=us-east-2 \
BUCKET_NAME=www.hallastech.com \
DISTRIBUTION_ID=E33Q8QG2BXCEVO \
./scripts/sync-site.sh
```
