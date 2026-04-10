# Agent Guide

## Repository Overview

This monorepo contains three active projects that together form the CSearch congressional data platform:

| Directory | Language | Role |
|---|---|---|
| `backend/scraper/` | Rust + Python | Data ingest pipeline — fetches, parses, and writes congress data to Postgres |
| `backend/api/` | Node.js (Fastify) | REST API — serves bill and vote data from Postgres to the frontend |
| `frontend/` | Nuxt 4 (Vue 3) | Static frontend — deployed to S3/CloudFront at csearch.org |

Supporting infrastructure lives in `argo/` (Argo CD applications), `k8s/` (Kubernetes manifests), and archived legacy material under `k8s/archive/legacy/`, plus older scripts such as `deploy.sh`.

---

## Project 1: backend/scraper

### What it does
Runs as a Kubernetes CronJob. Schedule varies by environment. Each run:
1. Calls the vendored Python scraper (`backend/scraper/congress/`) to fetch updated bill XML and vote JSON from GovInfo and congress.gov
2. Parses those files in Rust, skipping unchanged files via SHA-256 hash caching
3. Upserts normalized rows into Postgres (bills, bill_actions, bill_cosponsors, bill_subjects, bill_committees, votes, vote_members)

### Key files
- `backend/scraper/src/main.rs` — orchestration, feature flags (`RUN_BILLS`, `RUN_VOTES`)
- `backend/scraper/src/bills.rs` — XML/JSON bill parsing and ingest; bill congress range 93–current
- `backend/scraper/src/votes.rs` — vote JSON parsing and ingest; vote congress range 101–current
- `backend/scraper/src/config.rs` — config loading and runtime path resolution
- `backend/scraper/src/python.rs` — Python task runner
- `backend/scraper/src/hashes.rs` — file hash cache (persisted to host volume so restarts skip unchanged files)
- `backend/scraper/src/db.rs` — database writes and upsert logic
- `backend/scraper/schema.sql` — Postgres bootstrap schema (applied on first container start)
- `backend/scraper/congress/tasks/utils.py` — scraper HTTP client (scrapelib, 30 req/min rate limit)

### Congress number ranges
- Bills: congress 93 to current
- Votes: congress 101 to current (House vote records start at 101st Congress / 1989)
- Current congress is computed dynamically as `(year - 1789) / 2 + 1`

### Build and push (amd64)
```bash
# Run from repo root — Dockerfile uses paths relative to root
source .env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-updater:latest" \
  -f backend/scraper/Dockerfile .
```

### Trigger a manual run on the cluster
```bash
kubectl create job csearch-rscraper-manual-$(date +%s) --from=cronjob/csearch-rscraper
kubectl logs -f job/<job-name>
```

### Environment variables (k8s CronJob)
| Variable | Description |
|---|---|
| `CONGRESSDIR` | Root directory; congress data at `$CONGRESSDIR/congress/`, bill data at `$CONGRESSDIR/data/` |
| `POSTGRESURI` | Postgres hostname |
| `DB_USER` / `DB_PASSWORD` / `DB_NAME` | Postgres credentials (from ConfigMap/Secret) |
| `RUN_BILLS` | Enable bill ingest (default: `true`) |
| `RUN_VOTES` | Enable vote ingest (default: `true`) |

### Volume mounts (k8s)
| Container path | Host path | Purpose |
|---|---|---|
| `/srv/csearch/congress` | environment-specific host path | Scraped data, Python scraper, raw source files |
| `/srv/csearch/data` | environment-specific host path | Hash caches and ingest bookkeeping |

### Apply active k8s changes
```bash
kubectl apply -f k8s/netcup-scraper/cronjob.yaml
```

### Safe editing rules
- `backend/scraper/congress/` is vendored upstream Python code; edit only when fetch behavior or upstream formats change
- Bills XML parser tries new schema (v3.0.0) first for all congresses, falls back to legacy
- Vote JSON: `bill.congress` and `bill.number` are integers; vote position keys are normalized (Yea/Aye→yea, Nay/No→nay, Guilty→guilty, speaker candidate names stored as-is)

---

## Project 2: backend/api

### What it does
Fastify REST API serving bill and vote data from Postgres. Runs as a 2-replica Kubernetes Deployment, exposed at `https://api.csearch.org`.

### Key files
- `backend/api/routes/` — route handlers (bills, votes, latest, search, explore)
- `backend/api/controllers/db.js` — knex Postgres connection
- `backend/api/services/exploreQueries.js` — pre-built analytical SQL queries for the explore endpoint

### Key endpoints
| Method | Path | Description |
|---|---|---|
| `GET` | `/latest/:billtype` | 500 most recently active bills, sorted by `latest_action_date DESC NULLS LAST` |
| `GET` | `/search/:table/:filter` | Full-text bill/vote search |
| `GET` | `/bills/:billtype/:congress/:number` | Single bill detail with actions, cosponsors, votes |
| `GET` | `/bills/bynumber/:number` | All bill types matching a bill number, sorted most recent first |
| `GET` | `/explore/:query` | Pre-built analytical queries |

### Build and push (amd64)
```bash
source .env.prod
cd backend/api
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-api:latest" .
```

### Deploy to cluster
```bash
# After image push
kubectl rollout restart deployment/csearch-api
kubectl rollout status deployment/csearch-api

# After active manifest changes
kubectl apply -f k8s/netcup-core/api.yaml
```

### Direct local run
```bash
cd backend/api
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 npm run dev
```

---

## Project 3: frontend

### What it does
Nuxt 4 static site (SSG). Production builds are generated with `nuxt generate`, synced to S3, and served via CloudFront. The cluster-hosted frontend path uses an nginx container that serves the generated Nuxt output and injects its API origin at runtime.

### Key files
- `frontend/pages/bills/[category]/index.vue` — bill list with search, sort toggle, and 100-row pagination
- `frontend/pages/bills/[category]/[congress]/[number].vue` — bill detail
- `frontend/pages/votes/index.vue` — vote browser
- `frontend/pages/explore.vue` — analytical query explorer
- `frontend/assets/css/main.css` — global component styles
- `frontend/composables/useCongressApi.ts` — API client (prefers runtime-injected `NUXT_API_SERVER`, falls back to the Nuxt default)
- `frontend/composables/useApiBase.ts` — resolves the browser runtime API origin from `runtime-config.js`
- `frontend/Dockerfile.nginx` — generic nginx container image for the dev frontend deployment
- `frontend/types/congress.ts` — shared TypeScript types and bill type constants
- `frontend/deploy.sh` — one-command build + S3 sync + CloudFront invalidation

### Production deploy
```bash
cd frontend
bash deploy.sh
```

`deploy.sh` does:
1. Sources `../.env.prod` for `NUXT_API_SERVER`, `S3_BUCKET`, and `CF_DIST_CSEARCH`
2. Defaults `NUXT_API_SERVER` to `https://api.csearch.org` for the generated site
3. Runs `npx nuxt generate`
4. Syncs `.output/public` to S3
5. Invalidates CloudFront

### Argo-managed cluster deploys

The default Kubernetes deployment path now centers on Argo CD:

- `argo/applications/csearch-netcup-db.yaml` syncs `k8s/netcup-db/`
- `argo/applications/csearch-netcup-core.yaml` syncs `k8s/netcup-core/`
- `argo/applications/csearch-netcup-scraper.yaml` syncs `k8s/netcup-scraper/`
- `argo/applications/csearch-netcup-test-frontend.yaml` syncs `k8s/netcup-test-frontend/`

The existing workflow at `.github/workflows/mars-images.yml` still automates image builds and tag updates for the frontend-oriented path already wired in CI, but Argo itself is now the default deployment mechanism documented in this repo.

If you need to build the nginx frontend image manually:

```bash
source .env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-frontend:latest" \
  -f frontend/Dockerfile.nginx \
  frontend
```

### Local dev
```bash
cd frontend
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```

### Notes
- Production deploy is the S3/CloudFront path, not a Kubernetes frontend deployment
- The default production API origin is `https://api.csearch.org`
- The default Argo-managed cluster apps are `csearch-netcup-db`, `csearch-netcup-core`, `csearch-netcup-scraper`, and `csearch-netcup-test-frontend`
- Dynamic route segments use Nuxt bracket syntax (`[category]`, `[congress]`, `[number]`) — required by the framework
- CloudFront distribution IDs are stored in `.env.prod` (`CF_DIST_CSEARCH`, `CF_DIST_CONGRESS`)
- Bill list fetches 500 rows from the API and paginates 100 at a time client-side

---

## Cluster Overview

- **Registry**: `$REGISTRY` (set in `.env.prod`)
- **Server**: `$CLUSTER_HOST` (set in `.env.prod`)
- **Namespace**: `default`
- **Congress data on host**: environment-specific; check the active scraper manifest for the context you are working in

### k8s manifest structure
```
k8s/
├── netcup-db/             — Default Argo-managed Postgres manifests
├── netcup-core/           — Default Argo-managed API, Redis, and ingress
├── netcup-scraper/        — Default Argo-managed scraper CronJob
├── netcup-test-frontend/  — Default Argo-managed test frontend
└── registry-pull-secret.yaml
```

### Argo applications
```text
argo/applications/
├── csearch-netcup-db.yaml
├── csearch-netcup-core.yaml
├── csearch-netcup-scraper.yaml
└── csearch-netcup-test-frontend.yaml
```

### Useful kubectl commands
```bash
# Inspect Argo applications
kubectl --context mars get applications -n argocd

# Check running pods
kubectl get pods

# Tail updater job logs
kubectl logs -f job/<job-name>

# Trigger a manual updater run
kubectl create job csearch-rscraper-manual-$(date +%s) --from=cronjob/csearch-rscraper
```
