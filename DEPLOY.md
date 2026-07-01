# Deployment Guide

How to build and deploy each component of CSearch end to end.

---

## Architecture overview

| Component | Environment | Mechanism | URL |
| --- | --- | --- | --- |
| Frontend | Cloudflare Pages | GitHub Actions | `https://csearch.org` |
| API + Redis | netcup | ArgoCD (Git-driven) | `https://api.csearch.org` |
| API + Redis | freya | Manual (buildx + kubectl) | `192.168.1.156:3000` (LAN) |
| Postgres | netcup | ArgoCD (Git-driven) | — |
| Postgres | freya | Manual (kubectl, `default` ns) | — |
| Scraper CronJob | netcup | ArgoCD (Git-driven) | — |
| Scraper CronJob | freya | Manual (buildx + kubectl) | — |
| NLP Pipeline | freya | CronJob (`default` ns) | — |

**Git branches:**
- `main` → netcup (production)
- `freya` → freya (dev/secondary)

> **⚠️ freya is currently deployed manually, not by ArgoCD.** As of 2026-06 the
> freya cluster has no `argocd` namespace and no Argo Image Updater; every
> workload runs in the **`default`** namespace and is updated with
> `kubectl --context freya`. **Pushing to the `freya` branch does not deploy
> anything.** The netcup sections below still describe the intended GitOps flow;
> the freya sections describe the manual reality. See the per-component sections
> for the actual freya commands.

**Image registry:** `registry.s8njee.com` — user `sanjee`, password in GitHub Actions secret `REGISTRY_PASSWORD` and local keychain.

---

## Images — build and push

**CI workflow:** `.github/workflows/build-images.yml`

Triggers on push to `main` or `freya` touching `backend/api/**`,
`backend/mcp/**`, `backend/scraper/**`, `backend/nlp/**`, `frontend/**`, or the
workflow file itself. Also supports `workflow_dispatch`.

| Image | Dockerfile | Used by |
| --- | --- | --- |
| `csearch-fastapi:<git-sha>` | `backend/api/Dockerfile` | netcup API, freya API |
| `csearch-mcp:<git-sha>` | `backend/mcp/Dockerfile` | netcup MCP |
| `csearch-updater:<git-sha>` | `backend/scraper/Dockerfile` | netcup scraper, freya scraper |
| `csearch-frontend:<git-sha>` | `frontend/Dockerfile.nginx` | freya nginx frontend |
| `csearch-upserter:latest` | `backend/nlp/project-tarp/Dockerfile.upserter` | base image for tarp-updater |
| `csearch-tarp-updater:<git-sha>` | `backend/nlp/project-tarp/Dockerfile.nightly-updater` | netcup data-pipeline, freya data-pipeline |

CI tags deployable app images with both `:latest` and `:<git-sha>`. Netcup
manifests deploy the SHA tags through `k8s/netcup-*/kustomization.yaml`; `:latest`
is only a convenience tag for manual/dev use.

### Manual build

```bash
# FastAPI — build context must be repo root (includes backend/api/sql/)
docker build -f backend/api/Dockerfile -t registry.s8njee.com/csearch-fastapi:latest .
docker push registry.s8njee.com/csearch-fastapi:latest

# Scraper — build context is also repo root
docker build -f backend/scraper/Dockerfile -t registry.s8njee.com/csearch-updater:latest .
docker push registry.s8njee.com/csearch-updater:latest

# MCP
docker build -f backend/mcp/Dockerfile -t registry.s8njee.com/csearch-mcp:latest backend/mcp
docker push registry.s8njee.com/csearch-mcp:latest

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

Run from the repo root:

```bash
bash frontend/deploy.sh
```

That script:
1. Sources `../.env.prod` for `NUXT_API_SERVER` (defaults to `https://api.csearch.org`)
2. Runs `nuxt generate` → outputs to `frontend/.output/public`
3. Writes a deploy timestamp to `.output/public/meta.json`
4. Runs `npx wrangler pages deploy .output/public --project-name csearch --branch main`

Or manually step by step:

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

## Netcup release and rollback

Netcup deploys are auditable Git changes. The active image tags live in
`k8s/netcup-core/kustomization.yaml` and `k8s/netcup-scraper/kustomization.yaml`.
After CI has built the target commit, release it with:

```bash
scripts/release.sh <git-sha>
git push
```

With no argument, `scripts/release.sh` uses `HEAD`. Rollback is a normal Git
revert of the release commit:

```bash
git revert <release-commit>
git push
```

ArgoCD syncs the manifest change; no rollout restart is needed.

## API — netcup (production)

FastAPI backend at `https://api.csearch.org`. ArgoCD app `csearch-netcup-core`
watches `k8s/netcup-core` on `main`. Image updates are release commits created
by `scripts/release.sh`.

### Rotate OPENAI_API_KEY

```bash
echo -n 'sk-proj-...' | kubectl --context=netcup create secret generic csearch-api-openai \
  --from-literal=OPENAI_API_KEY="$(cat)" --dry-run=client -o yaml \
  | kubeseal --context=netcup -o yaml > k8s/netcup-core/csearch-api-openai-sealedsecret.yaml
git add k8s/netcup-core/csearch-api-openai-sealedsecret.yaml && git commit && git push
```

---

## API — freya (dev/secondary)

FastAPI backend at `192.168.1.156:3000` (LAN only), Deployment `csearch-api` in the
**`default`** namespace. **Deployed manually** — there is no ArgoCD app or Argo Image
Updater on freya, so pushing to the `freya` branch deploys nothing on its own.

### Deploy a new API image

```bash
# 1. Build + push linux/amd64. Registry auth is cached in the local keychain
#    (no docker login needed); build context is the repo ROOT. Tag :latest plus
#    the git sha for traceability.
SHA=$(git rev-parse --short HEAD)
docker buildx build --platform linux/amd64 -f backend/api/Dockerfile \
  -t registry.s8njee.com/csearch-fastapi:latest \
  -t "registry.s8njee.com/csearch-fastapi:$SHA" --push .

# 2. Roll out (deployment pins :latest with imagePullPolicy: Always; replicas=1,
#    so the old pod stays up until the new one is Ready).
kubectl --context freya rollout restart deploy/csearch-api
kubectl --context freya rollout status deploy/csearch-api
```

The CI workflow `build-images.yml` also builds + pushes `:latest` (on push to `main`
or `freya`, or via `workflow_dispatch`), but freya does **not** auto-pull it — you
still run the `rollout restart` above.

### Deploy manifest changes

```bash
kubectl --context freya apply -k k8s/freya-core   # and k8s/freya-db as needed
```

There is no auto-sync and no ArgoCD `selfHeal`, so manual `kubectl` changes persist.

### Set / rotate OPENAI_API_KEY

freya has no sealed-secrets controller, so apply the Secret directly. Semantic and
hybrid search return **503** ("not configured") until this is set — the secret
ships with an empty value by default:

```bash
kubectl --context freya create secret generic csearch-api-openai \
  --from-literal=OPENAI_API_KEY='sk-...' --dry-run=client -o yaml \
  | kubectl --context freya apply -f -
kubectl --context freya rollout restart deploy/csearch-api
```

---

## Database — netcup

PostgreSQL StatefulSet managed by ArgoCD app `csearch-netcup-db` watching `k8s/netcup-db` on `main`.

Schema is bootstrapped by the scraper on first run from `backend/scraper/schema.sql`. The `nlp` schema is bootstrapped separately by the NLP pipeline. ArgoCD does not manage migrations — apply them manually or via the scraper.

Nightly logical backups run via `postgres-b2-backup` after the
`postgres-b2-backup` Secret exists. See `docs/RESTORE.md` for secret creation,
manual backup, and restore-test steps.

---

## Database — freya

PostgreSQL StatefulSet `postgres` in the **`default`** namespace, applied manually
(`kubectl --context freya apply -k k8s/freya-db`). The public schema is bootstrapped
from `backend/scraper/schema.sql` on first scraper run; the `nlp` schema is created
by the NLP pipeline. freya has **no `public.schema_migrations` table**, so the
`db/migrate.py` chain (e.g. `0007`, `0008`) is not tracked or applied here — apply
migration SQL manually when needed:

```bash
kubectl --context freya exec -i sts/postgres -- \
  psql -U postgres -d csearch < db/migrations/0008_bill_uid.sql
```

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

Kubernetes CronJob in the **`default`** namespace, applied manually
(`kubectl --context freya apply -k k8s/freya-scraper`). Update its image like the
API — build + push `csearch-updater:latest`, then the next scheduled run (or a
manual job) pulls `:latest`.

### Run manually

```bash
kubectl --context=freya create job --from=cronjob/csearch-scraper csearch-scraper-manual
kubectl --context=freya logs -f job/csearch-scraper-manual
```

---

## Data pipeline — unified (scraper + NLP)

Both environments run `csearch-data-pipeline`, a single CronJob that sequences the scraper (initContainer) then the NLP updater (main container). Schedule: 5 AM America/Chicago daily.

- netcup: managed by ArgoCD app `csearch-netcup-scraper` (`k8s/netcup-scraper` on `main`)
- freya: applied manually (`k8s/freya-scraper`, `default` ns) — `kubectl --context freya apply -k k8s/freya-scraper`

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

## ArgoCD reference (netcup)

> **freya does not currently run ArgoCD.** The freya rows below are the *intended*
> GitOps layout only — those apps are not deployed, and the `argocd` / `-n argocd`
> commands in this section apply to **netcup only**. Deploy freya with the manual
> `kubectl --context freya` commands in the per-component sections above.

| Application | Cluster | Branch | Manifest path | Sync wave |
| --- | --- | --- | --- | --- |
| `csearch-netcup-db` | netcup | `main` | `k8s/netcup-db` | -10 |
| `csearch-netcup-core` | netcup | `main` | `k8s/netcup-core` | 0 |
| `csearch-netcup-scraper` | netcup | `main` | `k8s/netcup-scraper` | 10 |
| `csearch-netcup-test-frontend` | netcup | `rscraper` | `k8s/netcup-test-frontend` | — |
| `csearch-freya-db` | freya | `freya` | `k8s/freya-db` | — (not deployed; manual) |
| `csearch-freya-core` | freya | `freya` | `k8s/freya-core` | — (not deployed; manual) |
| `csearch-freya-scraper` | freya | `freya` | `k8s/freya-scraper` | — (not deployed; manual) |

netcup apps have `selfHeal: true` and `prune: true` — manual `kubectl` changes are reverted, so always push to the watched branch. freya has no ArgoCD, so manual `kubectl --context freya` changes persist.

### Useful commands

```bash
# Force sync an app (netcup)
argocd app sync csearch-netcup-core

# Check app health across netcup
kubectl --context=netcup get applications -n argocd

# freya: no ArgoCD — inspect workloads directly in the default namespace
kubectl --context freya get deploy,sts,cronjob,pods
```
