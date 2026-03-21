# Engineering Guide

This document is the practical onboarding guide for engineers working in CSearch.

Use it to answer two questions quickly:

1. Where should I start for the change I need to make?
2. How does this repo actually behave in development and production?

## Mental Model

Think about the system as four layers with clear ownership:

| Layer | Owns | Main code |
| --- | --- | --- |
| Ingest | Downloading and normalizing source data | `backend/scraper/` |
| Storage | Canonical bill and vote records | PostgreSQL initialized from `backend/scraper/schema.sql` |
| Query | API shapes, caching, and search behavior | `backend/api/` |
| Presentation | User-facing pages and browser/runtime API targeting | `frontend/` |

That ownership model helps when you decide where a bug really lives:

- If the data is missing from Postgres, start in the scraper.
- If Postgres has the data but the frontend does not, start in the API contract.
- If the API returns the right data but the page is wrong, start in the frontend.

## What To Read Before Editing

### If you are changing ingest logic

Read:

1. [`backend/scraper/README.md`](../backend/scraper/README.md)
2. [`ARCHITECTURE.md`](../ARCHITECTURE.md)
3. The relevant parser file:
   - `backend/scraper/bills.go`
   - `backend/scraper/votes.go`

### If you are changing API behavior

Read:

1. [`backend/api/README.md`](../backend/api/README.md)
2. The relevant route in `backend/api/routes/`
3. `backend/api/controllers/db.js`

### If you are changing UI behavior

Read:

1. [`frontend/README.md`](../frontend/README.md)
2. `frontend/composables/useCongressApi.ts`
3. The page or component you plan to touch

### If you are changing deployment or operations

Read:

1. [`ARCHITECTURE.md`](../ARCHITECTURE.md)
2. `deploy.sh`
3. The relevant manifest in `k8s/`

## Common Tasks And Where To Work

| Goal | Usually edit these places |
| --- | --- |
| Add a new bill field to an existing page | `backend/scraper/bills.go`, `backend/scraper/query.sql`, `backend/api/routes/*.js`, `frontend/types/congress.ts`, relevant Vue page/component |
| Add a new vote-derived metric | `backend/scraper/votes.go`, possibly `backend/scraper/schema.sql`, then API route or explore query, then frontend |
| Add an explore query | `backend/scraper/explore.sql`, `backend/api/services/exploreQueries.js`, `frontend/pages/explore.vue` |
| Fix stale API responses | `backend/api/utils/cache.js`, the relevant route, the Redis config, and any flow that clears or refreshes cache |
| Fix the wrong API target in a deployed frontend | `frontend/composables/useApiBase.ts`, `frontend/docker-entrypoint.sh`, or the relevant manifest / deploy script |
| Change a production schedule | `k8s/scraper/cronjob.yaml` or `k8s/frontend/deploy-cronjob.yaml` |

## Important Sources Of Truth

These are the files engineers most often assume are duplicated when they are not:

| Concern | Source of truth |
| --- | --- |
| Database schema bootstrap | `backend/scraper/schema.sql` |
| Generated Go query code | `backend/scraper/query.sql` and `backend/scraper/sqlc.yaml` |
| Explore SQL | `backend/scraper/explore.sql` |
| Live Kubernetes manifests | `k8s/` at the repo root |
| Frontend production deploy flow | `frontend/deploy.sh` |
| Full platform deploy flow | `deploy.sh` |
| Shared logging infrastructure | External `k8s_study/logging/` stack plus CSearch dashboards in `k8s/logging/` |

## Local Development Workflows

### Full stack

```bash
docker-compose up --build
```

Use this when:

- you need the system running end to end
- you want the least amount of setup
- you are validating how the frontend, API, and database work together

### API-focused work

```bash
docker-compose up postgres api
cd backend/api
npm test
```

Use this when:

- you are changing route logic or query behavior
- you do not need the frontend running

### Frontend-focused work

```bash
docker-compose up postgres api
cd frontend
npm install
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```

Use this when:

- you want hot reload
- you are changing page layout or UI behavior

### Scraper-focused work

Use the compose stack first unless you need to debug the scraper directly. The scraper expects `CONGRESSDIR` to point at a runtime root that contains:

- `congress/` for the vendored Python scraper and its downloaded raw data
- `data/` for hash caches

See [`backend/scraper/README.md`](../backend/scraper/README.md) for the direct run setup.

## Debugging Playbooks

### Data is missing from the site

Work from left to right:

1. Confirm the scraper downloaded source files under the congress data directory
2. Confirm the normalized data exists in Postgres
3. Confirm the API route returns the data
4. Confirm the frontend calls the expected endpoint

### Data exists in Postgres but not in the API

Check:

- the route file in `backend/api/routes/`
- any per-route cache behavior
- any derived query shape in `backend/api/services/exploreQueries.js`

### The frontend is talking to the wrong API

Remember the API base resolution order:

1. `window.__CSEARCH_RUNTIME_CONFIG__.API_SERVER` from `runtime-config.js`
2. Nuxt public runtime config
3. The default value from `frontend/nuxt.config.ts`

If the wrong API is used in a deployed nginx container, the fix is often in:

- `frontend/docker-entrypoint.sh`
- the Kubernetes manifest that sets `NUXT_API_SERVER`

### The scraper says nothing changed when you expected updates

Check the hash caches. The scraper skips files whose SHA-256 digest matches the last successful ingest. Relevant files are stored under the runtime `data/` directory, not inside the API or frontend.

### You want logs shipped off-cluster

This repo still includes the older Fluent Bit HTTP shipper in `k8s/logging/`.

If log shipping is not active, verify in this order:

1. `LOG_SHIP_HTTP_HOST`, `LOG_SHIP_HTTP_PORT`, and `LOG_SHIP_HTTP_URI` are set in `.env.prod`
2. `bash deploy.sh` applied `k8s/logging/fluent-bit-config.yaml`, `k8s/logging/fluent-bit-rbac.yaml`, and `k8s/logging/fluent-bit-daemonset.yaml`
3. `daemonset/csearch-fluent-bit` is running
4. the API and scraper are still emitting JSON log lines to stdout

## Things That Commonly Confuse New Contributors

### There are two Kubernetes areas in the repo

Use the top-level `k8s/` directory for the current platform. The manifests under `backend/api/k8s/` are older service-local artifacts and examples.

### The frontend has multiple deployment modes

There are four frontend execution modes you may encounter:

1. Local `nuxt dev`
2. Production static generation to S3 + CloudFront
3. nginx container deployment for cluster-based environments like `mars`
4. Deploy-container execution for scheduled static publishing

The correct place to edit depends on which mode you are changing.

For `mars`, the frontend and dev API are split across different manifests:

- `k8s/frontend/mars-deployment.yaml` sets `NUXT_API_SERVER=http://api-dev`
- `k8s/dev/api.yaml` defines the `api-dev` deployment and its `redis-dev` side service
- the `mars` dev API currently points at the shared `postgres` service and uses the `csearch-api:redis` image tag

### The scraper is both Go and Python

That is intentional:

- Python handles source acquisition through the vendored `congress` project
- Go handles normalization, deduplication, and database writes

If the problem is with downloaded source files, you may need the vendored Python code. If the problem is with normalized records in Postgres, you almost certainly need the Go code.

### Some files are generated or copied

- `backend/scraper/csearch/*.go` is generated by `sqlc`
- `backend/api/sql/explore.sql` is copied from `backend/scraper/explore.sql` during the full deploy flow

If you change the generated or copied artifact directly, your change may be overwritten later.

## Suggested First-Day Checklist

1. Run `docker-compose up --build`
2. Open the frontend, API, and database locally
3. Read the README for the area you expect to change most often
4. Pick one user-facing page and trace the data flow all the way back to the scraper
5. Read `deploy.sh` once so the production deploy path is not a black box later
