# Hallas Tech Website

Static SDVOSB business website for `www.hallastech.com`.

The site is generated with Jinja2:

- Edit content in `content/site.json`.
- Edit page structure in `templates/index.html.j2`.
- Run `scripts/render_site.py` to generate `index.html`.
- Serve the generated static files with Podman or upload them to S3.

There is no runtime JavaScript.

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

Short version from this directory:

```bash
HOSTED_ZONE_ID=Z1234567890ABC ./scripts/deploy-infra.sh
./scripts/render_site.py
./scripts/sync-site.sh
```

The infrastructure stack is defined in `aws/static-site.yaml`.

## Update The Live Site

After editing `content/site.json`, `templates/index.html.j2`, `styles.css`, or files under `assets/`:

```bash
./scripts/render_site.py
./scripts/sync-site.sh
```
