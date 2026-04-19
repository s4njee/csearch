# Deployment Guide

How to build and deploy each component of CSearch end to end.

---

## Architecture overview

| Component | Environment | Mechanism | URL |
| --- | --- | --- | --- |
| Frontend | Cloudflare Pages | GitHub Actions | `https://csearch.org` |
| API + Redis | netcup | ArgoCD (Git-driven) | `https://api.csearch.org` |
| API + Redis | freya | ArgoCD + Image Updater (auto) | `192.168.1.156:3000` (LAN) |
| Postgres | netcup | ArgoCD (Git-driven) | — |
| Postgres | freya | ArgoCD (Git-driven) | — |
| Scraper CronJob | netcup | ArgoCD (Git-driven) | — |
| Scraper CronJob | freya | ArgoCD + Image Updater (auto) | — |
| NLP Pipeline | freya | CronJob (`csearch-nlp` ns) | — |

**Git branches:**
- `main` → netcup (production)
- `freya` → freya (dev/secondary)

**Image registry:** `registry.s8njee.com` — user `sanjee`, password in GitHub Actions secret `REGISTRY_PASSWORD` and local keychain.

---

## Images — build and push

**CI workflow:** `.github/workflows/build-images.yml`

Triggers on push to `main` touching `backend/api/**`, `backend/scraper/**`, `frontend/**`, or the workflow file itself. Also supports `workflow_dispatch`.

| Image | Dockerfile | Used by |
| --- | --- | --- |
| `csearch-fastapi:latest` | `backend/api/api_fastapi/Dockerfile` | netcup API, freya API |
| `csearch-updater:latest` | `backend/scraper/Dockerfile` | netcup scraper, freya scraper |
| `csearch-frontend:latest` | `frontend/Dockerfile.nginx` | freya nginx frontend |
| `csearch-upserter:latest` | `backend/nlp/project-tarp/Dockerfile.upserter` | base image for tarp-updater |
| `csearch-tarp-updater:latest` | `backend/nlp/project-tarp/Dockerfile.nightly-updater` | netcup data-pipeline, freya data-pipeline |

CI tags each image with both `:latest` and `:<git-sha>`.

### Manual build

```bash
# FastAPI — build context must be repo root (includes backend/api/sql/)
docker build -f backend/api/api_fastapi/Dockerfile -t registry.s8njee.com/csearch-fastapi:latest .
docker push registry.s8njee.com/csearch-fastapi:latest

# Scraper — build context is also repo root
docker build -f backend/scraper/Dockerfile -t registry.s8njee.com/csearch-updater:latest .
docker push registry.s8njee.com/csearch-updater:latest

# Frontend nginx
docker build -f frontend/Dockerfile.nginx -t registry.s8njee.com/csearch-frontend:latest frontend/
docker push registry.s8njee.com/csearch-frontend:latest
```

Registry login:

```bash
docker login registry.s8njee.com -u sanjee
```

---

## Frontend — Cloudflare Pages

Nuxt 4 static site deployed to Cloudflare Pages project **csearch** (`csearch.org`).

### Manual deploy (local)

Wrangler uses OAuth — `npx wrangler whoami` should show `sanjee.yogeswaran@gmail.com`.

```bash
cd frontend
NUXT_API_SERVER=https://api.csearch.org npm run generate
echo "{\"updated_at\": \"$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)\"}" > .output/public/meta.json
npx wrangler pages deploy .output/public --project-name csearch --branch main
```

### CI deploy

**Workflow:** `.github/workflows/frontend-cloudflare-deploy.yml`

**Triggers:** push to `main` touching `frontend/**`; daily at 12:00 UTC; `workflow_dispatch`.

**Required secrets:**

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Pages:Edit permission |
| `CLOUDFLARE_ACCOUNT_ID` | `c81fc0807ec37ef9967dd71b7e8c0f62` |

**Required variables:**

| Variable | Value |
| --- | --- |
| `NUXT_API_SERVER` | `https://api.csearch.org` |
| `CF_PAGES_PROJECT` | `csearch` |

---

## API — netcup (production)

FastAPI backend at `https://api.csearch.org`. ArgoCD app `csearch-netcup-core` watches `k8s/netcup-core` on `main`.

Image updates require a Git commit — ArgoCD syncs on every push to `main`. To also force an immediate rollout after pushing a new `:latest`:

```bash
kubectl --context=netcup rollout restart deploy/csearch-api
```

### Rotate OPENAI_API_KEY

```bash
echo -n 'sk-proj-...' | kubectl --context=netcup create secret generic csearch-api-openai \
  --from-literal=OPENAI_API_KEY="$(cat)" --dry-run=client -o yaml \
  | kubeseal --context=netcup -o yaml > k8s/netcup-core/csearch-api-openai-sealedsecret.yaml
git add k8s/netcup-core/csearch-api-openai-sealedsecret.yaml && git commit && git push
```

---

## API — freya (dev/secondary)

FastAPI backend at `192.168.1.156:3000` (LAN only). ArgoCD app `csearch-freya-core` watches `k8s/freya-core` on `freya`.

**Image updates are automatic.** Argo Image Updater polls `registry.s8njee.com` every 2 minutes and rolls out new `csearch-fastapi:latest` digests without a Git commit.

```bash
# Check image updater status
kubectl --context=freya logs -n argocd deploy/argocd-image-updater-controller --tail=50
```

### Deploy manifest changes

Push to `freya` branch — ArgoCD syncs automatically.

### Rotate OPENAI_API_KEY

```bash
echo -n 'sk-proj-...' | kubectl --context=freya create secret generic csearch-api-openai \
  --from-literal=OPENAI_API_KEY="$(cat)" --dry-run=client -o yaml \
  | kubeseal --context=freya -o yaml > k8s/freya-core/csearch-api-openai-sealedsecret.yaml
git add k8s/freya-core/csearch-api-openai-sealedsecret.yaml && git commit -m "rotate openai key (freya)" && git push origin freya
```

---

## Database — netcup

PostgreSQL StatefulSet managed by ArgoCD app `csearch-netcup-db` watching `k8s/netcup-db` on `main`.

Schema is bootstrapped by the scraper on first run from `backend/scraper/schema.sql`. The `nlp` schema is bootstrapped separately by the NLP pipeline. ArgoCD does not manage migrations — apply them manually or via the scraper.

---

## Database — freya

PostgreSQL StatefulSet managed by ArgoCD app `csearch-freya-db` watching `k8s/freya-db` on `freya`.

---

## Scraper — netcup

Kubernetes CronJob managed by ArgoCD app `csearch-netcup-scraper` watching `k8s/netcup-scraper` on `main`. Runs daily at 5 AM America/Chicago (after GovInfo updates).

### Run manually

```bash
kubectl --context=netcup create job --from=cronjob/csearch-scraper csearch-scraper-manual
kubectl --context=netcup logs -f job/csearch-scraper-manual
```

### Toggle what runs

```bash
# Bills only
kubectl --context=netcup set env cronjob/csearch-scraper RUN_BILLS=true RUN_VOTES=false

# Votes only
kubectl --context=netcup set env cronjob/csearch-scraper RUN_BILLS=false RUN_VOTES=true

# Both (default)
kubectl --context=netcup set env cronjob/csearch-scraper RUN_BILLS=true RUN_VOTES=true
```

---

## Scraper — freya

Kubernetes CronJob managed by ArgoCD app `csearch-freya-scraper` watching `k8s/freya-scraper` on `freya`. Image is auto-updated by Argo Image Updater.

### Run manually

```bash
kubectl --context=freya create job --from=cronjob/csearch-scraper csearch-scraper-manual
kubectl --context=freya logs -f job/csearch-scraper-manual
```

---

## Data pipeline — unified (scraper + NLP)

Both environments run `csearch-data-pipeline`, a single CronJob that sequences the scraper (initContainer) then the NLP updater (main container). Schedule: 5 AM America/Chicago daily.

- netcup: managed by ArgoCD app `csearch-netcup-scraper` (`k8s/netcup-scraper` on `main`)
- freya: managed by ArgoCD app `csearch-freya-scraper` (`k8s/freya-scraper` on `freya`)

### Run manually

```bash
# netcup
kubectl --context=netcup create job --from=cronjob/csearch-data-pipeline csearch-data-pipeline-manual
kubectl --context=netcup logs -f job/csearch-data-pipeline-manual -c scraper
kubectl --context=netcup logs -f job/csearch-data-pipeline-manual -c nlp-updater

# freya
kubectl --context=freya create job --from=cronjob/csearch-data-pipeline csearch-data-pipeline-manual
kubectl --context=freya logs -f job/csearch-data-pipeline-manual -c scraper
kubectl --context=freya logs -f job/csearch-data-pipeline-manual -c nlp-updater
```

### Notes

- Only bills with changed text incur OpenAI API calls (content hashing skips unchanged bills)
- See `backend/nlp/project-tarp/UPDATE.md` for cost estimates and runbook
- `csearch-upserter` is an intermediate image (base for `csearch-tarp-updater`) — it is not deployed directly

---

## Syncing environments

**netcup → freya** (push production changes to dev):

```bash
git checkout freya
git merge main   # or: git cherry-pick <commit>
git push origin freya
```

**freya → netcup** (promote dev changes to production):

```bash
git checkout main
git merge freya   # or: git cherry-pick <commit>
git push origin main
```

---

## ArgoCD reference

| Application | Cluster | Branch | Manifest path | Sync wave |
| --- | --- | --- | --- | --- |
| `csearch-netcup-db` | netcup | `main` | `k8s/netcup-db` | -10 |
| `csearch-netcup-core` | netcup | `main` | `k8s/netcup-core` | 0 |
| `csearch-netcup-scraper` | netcup | `main` | `k8s/netcup-scraper` | 10 |
| `csearch-netcup-test-frontend` | netcup | `rscraper` | `k8s/netcup-test-frontend` | — |
| `csearch-freya-db` | freya | `freya` | `k8s/freya-db` | -10 |
| `csearch-freya-core` | freya | `freya` | `k8s/freya-core` | 0 |
| `csearch-freya-scraper` | freya | `freya` | `k8s/freya-scraper` | 0 |

All apps have `selfHeal: true` and `prune: true` — manual `kubectl` changes are reverted. Always push to the watched branch.

### Useful commands

```bash
# Force sync an app
argocd app sync csearch-netcup-core

# Check app health across netcup
kubectl --context=netcup get applications -n argocd

# Check app health across freya
kubectl --context=freya get applications -n argocd

# Check image updater on freya
kubectl --context=freya logs -n argocd deploy/argocd-image-updater-controller --tail=30
```
