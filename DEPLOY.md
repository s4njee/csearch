# Deployment Guide

How to build and deploy each component of CSearch end to end.

---

## Frontend — Cloudflare Pages

The frontend is a statically generated Nuxt 4 app deployed to Cloudflare Pages project **csearch** (`csearch.org`).

### Manual deploy (local)

Wrangler uses OAuth — `npx wrangler whoami` should show `sanjee.yogeswaran@gmail.com`. No API token needed locally.

```bash
cd frontend
NUXT_API_SERVER=https://api.csearch.org npm run generate
echo "{\"updated_at\": \"$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)\"}" > .output/public/meta.json
npx wrangler pages deploy .output/public --project-name csearch --branch main
```

### CI deploy (GitHub Actions)

**Workflow:** `.github/workflows/frontend-s3-deploy.yml`

**Triggers:** push to `main` touching `frontend/**` or `.github/workflows/frontend-s3-deploy.yml`; daily at 12:00 UTC (keeps the site fresh with latest bill data); `workflow_dispatch`.

**Required GitHub Actions secrets:**

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Pages:Edit permission |
| `CLOUDFLARE_ACCOUNT_ID` | `c81fc0807ec37ef9967dd71b7e8c0f62` |

**Required GitHub Actions variables:**

| Variable | Value |
| --- | --- |
| `NUXT_API_SERVER` | `https://api.csearch.org` |
| `CF_PAGES_PROJECT` | `csearch` |

---

## API — netcup (production)

FastAPI backend at `https://api.csearch.org`. Managed by Argo CD app `csearch-netcup-core` watching `k8s/netcup-core` on `main`.

### Build and push image

**CI** (`.github/workflows/mars-images.yml`) builds and pushes on every push to `main` touching `backend/api/**`:

```bash
# What CI does — build context is repo root to include backend/api/sql/explore.sql
docker build -f backend/api/Dockerfile -t registry.s8njee.com/csearch-fastapi:latest .
docker push registry.s8njee.com/csearch-fastapi:latest
```

**Manually (from freya — amd64, has working Docker):**

```bash
# On freya
git clone https://github.com/s4njee/csearch.git && cd csearch
docker build -f backend/api/Dockerfile -t registry.s8njee.com/csearch-fastapi:latest .
docker push registry.s8njee.com/csearch-fastapi:latest
```

Registry credentials: `registry.s8njee.com`, user `sanjee` (password in keychain / `REGISTRY_PASSWORD` secret).

### Deploy

Argo CD (`csearch-netcup-core`) has `selfHeal: true` and watches `k8s/netcup-core` on `main`. Push manifest changes to `main` and Argo syncs automatically.

To force an immediate image refresh (after a new `:latest` push):

```bash
kubectl --context=netcup rollout restart deploy/csearch-api
```

### Add or rotate OPENAI_API_KEY (netcup)

```bash
echo -n 'sk-proj-...' | kubectl --context=netcup create secret generic csearch-api-openai \
  --from-literal=OPENAI_API_KEY="$(cat)" --dry-run=client -o yaml \
  | kubeseal --context=netcup -o yaml > k8s/netcup-core/csearch-api-openai-sealedsecret.yaml
git add k8s/netcup-core/csearch-api-openai-sealedsecret.yaml && git commit && git push
```

---

## API — freya (secondary)

FastAPI backend at `192.168.1.156:3000` (LAN only). Managed by Argo CD app `csearch-mars-core` watching `k8s/mars` on `fastapi-api-rewrite`.

### Image updates (automatic)

Argo Image Updater is installed on freya (`argocd-image-updater-controller` in namespace `argocd`). It polls `registry.s8njee.com` every 2 minutes and automatically rolls out new `csearch-fastapi:latest` digests — no git commit required.

To check status:

```bash
kubectl --context=freya logs -n argocd deploy/argocd-image-updater-controller --tail=50
```

### Deploy manifest changes

Push to the `fastapi-api-rewrite` branch. Argo syncs automatically.

```bash
# From the fastapi-api-rewrite worktree at /private/tmp/csearch-fastapi-api
git push origin fastapi-api-rewrite
```

### Add or rotate OPENAI_API_KEY (freya)

```bash
echo -n 'sk-proj-...' | kubectl --context=freya create secret generic csearch-api-openai \
  --from-literal=OPENAI_API_KEY="$(cat)" --dry-run=client -o yaml \
  | kubeseal --context=freya -o yaml > k8s/mars/csearch-api-openai-sealedsecret.yaml
# Commit to fastapi-api-rewrite branch and push
```

---

## Database — netcup

PostgreSQL managed by Argo CD app `csearch-netcup-db` watching `k8s/netcup-db` on `main`.

Schema is bootstrapped by the scraper on first run from `backend/scraper/schema.sql`. The `nlp` schema is bootstrapped separately by the NLP pipeline.

To apply schema changes:

1. Edit `backend/scraper/schema.sql`
2. Run a migration manually or let the scraper apply it on next run
3. Commit and push — Argo does not manage schema migrations directly

---

## Scraper — netcup

Kubernetes CronJob managed by Argo CD app `csearch-netcup-scraper` watching `k8s/netcup-scraper` on `main`.

### Build and push image

CI builds `csearch-updater:latest` on push to `main` touching `backend/scraper/**` (same workflow as the API: `.github/workflows/mars-images.yml`).

### Run manually

```bash
kubectl --context=netcup create job --from=cronjob/csearch-scraper csearch-scraper-manual
kubectl --context=netcup logs -f job/csearch-scraper-manual
```

Toggle what runs:

```bash
# Bills only
kubectl --context=netcup set env cronjob/csearch-scraper RUN_BILLS=true RUN_VOTES=false

# Votes only
kubectl --context=netcup set env cronjob/csearch-scraper RUN_BILLS=false RUN_VOTES=true
```

---

## NLP Pipeline — freya

Nightly CronJob in namespace `csearch-nlp` on freya. Source: `backend/nlp/` (git submodule).

### Run manually

```bash
kubectl --context=freya -n csearch-nlp create job --from=cronjob/tarp-nightly-updater nlp-manual
kubectl --context=freya -n csearch-nlp logs -f job/nlp-manual
```

### Operational notes

- Only bills with changed text incur OpenAI API calls (content hashing skips the rest)
- Logs at `/home/sanjee/nlp/tarp-data/logs/update-YYYY-MM-DD.log` on freya
- See `backend/nlp/project-tarp/UPDATE.md` for cost estimates and runbook

---

## Registry

Private registry at `registry.s8njee.com`. Images:

| Image | Built by | Used by |
| --- | --- | --- |
| `csearch-fastapi:latest` | CI / manual | netcup API, freya API |
| `csearch-updater:latest` | CI / manual | netcup scraper, freya scraper |
| `csearch-frontend:latest` | CI / manual | freya nginx frontend |

Push credentials: user `sanjee`, password in GitHub Actions secret `REGISTRY_PASSWORD` and macOS keychain.

---

## Argo CD reference

| Application | Cluster | Branch | URL |
| --- | --- | --- | --- |
| `csearch-netcup-core` | netcup | `main` | API + Redis |
| `csearch-netcup-db` | netcup | `main` | Postgres |
| `csearch-netcup-scraper` | netcup | `main` | Scraper CronJob |
| `csearch-netcup-test-frontend` | netcup | `rscraper` | `test.csearch.org` |
| `csearch-mars-core` | freya | `fastapi-api-rewrite` | API + Redis |
| `csearch-mars-db` | freya | `optimize` | Postgres (CNPG) |

All apps have `selfHeal: true` — manual kubectl changes are reverted. Always push to the watched branch.

### Useful commands

```bash
# Force sync
kubectl --context=netcup patch application csearch-netcup-core -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check app health
kubectl --context=netcup get applications -n argocd

# Check image updater on freya
kubectl --context=freya logs -n argocd deploy/argocd-image-updater-controller --tail=30
```
