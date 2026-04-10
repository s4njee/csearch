# Deployment Guide

## Frontend — Cloudflare Pages

The frontend is a statically generated Nuxt app deployed to Cloudflare Pages project **csearch**.

### Manual deploy (local)

Wrangler is authenticated via OAuth (`npx wrangler whoami` should show `sanjee.yogeswaran@gmail.com`).

```bash
cd frontend
NUXT_API_SERVER=https://api.csearch.org npm run generate
echo "{\"updated_at\": \"$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)\"}" > .output/public/meta.json
npx wrangler pages deploy .output/public --project-name csearch --branch main
```

### CI deploy (GitHub Actions)

Workflow: `.github/workflows/frontend-s3-deploy.yml` (triggers on push to `main` touching `frontend/**`, and daily at 12:00 UTC).

Required GitHub Actions **secrets**:
- `CLOUDFLARE_API_TOKEN` — Cloudflare API token with Pages:Edit permission
- `CLOUDFLARE_ACCOUNT_ID` — `c81fc0807ec37ef9967dd71b7e8c0f62`

Required GitHub Actions **variables**:
- `NUXT_API_SERVER` — `https://api.csearch.org`
- `CF_PAGES_PROJECT` — `csearch`

---

## API — Kubernetes (netcup)

FastAPI backend deployed via Argo CD (`csearch-netcup-core`) watching `k8s/netcup-core` on `main`.

- Ingress: `https://api.csearch.org`
- Image: `registry.s8njee.com/csearch-fastapi:latest`
- Registry: `registry.s8njee.com` (credentials in GitHub Actions secrets `REGISTRY_USERNAME` / `REGISTRY_PASSWORD`)

CI builds and pushes the image on push to `main` touching `backend/api_fastapi/**`.

---

## API — Kubernetes (freya)

FastAPI backend deployed via Argo CD (`csearch-mars-core`) watching `k8s/mars` on `fastapi-api-rewrite`.

- LoadBalancer: `192.168.1.156:3000`
- Image: `registry.s8njee.com/csearch-fastapi:latest`
- Argo Image Updater polls the registry every 2 minutes and rolls out new digests automatically (no git commits).
