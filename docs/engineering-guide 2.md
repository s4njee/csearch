# Engineering Guide

This is the practical onboarding guide for day-to-day work in CSearch. It answers three questions:

1. Where should I start for the change I need to make?
2. Which file is the source of truth?
3. What are the common patterns and pitfalls?

For deployment specifics, see [`deployment.md`](deployment.md). For caching details, see [`caching.md`](caching.md).

## Mental Model

Think about the platform as four product layers plus two operational layers:

| Layer | Owns | Main code |
| --- | --- | --- |
| Ingest | downloading and normalizing source data | `backend/scraper/` |
| Storage | canonical bill and vote records | Postgres initialized from `backend/scraper/schema.sql` |
| Query | API contracts, search, and caching | `backend/api/` |
| Presentation | pages, UX, and runtime API targeting | `frontend/` |
| Deploy | Argo applications and synced Kubernetes manifests | `argo/`, `k8s/netcup-*` |
| Observability | structured logs and shipping configuration | `k8s/logging/` |

Use this ownership model to localize bugs quickly:

- Data missing from Postgres → start in the scraper
- Postgres has the data but API is wrong → start in the route or query layer
- API is right but page is wrong → start in the frontend
- Code is right but behavior differs between environments → start in the Argo app or synced manifests

## Source-of-Truth Map

| Concern | Source of truth |
| --- | --- |
| Database schema bootstrap | `backend/scraper/schema.sql` |
| Scraper DB write logic | `backend/scraper/src/db.rs` |
| Explore SQL | `backend/scraper/explore.sql` |
| API cache implementation | `backend/api/utils/cache.js` |
| Default deployment entry points | `argo/applications/` |
| Default synced manifests | `k8s/netcup-db/`, `k8s/netcup-core/`, `k8s/netcup-scraper/`, `k8s/netcup-test-frontend/` |
| Logging shipper and collector config | `k8s/logging/` |

**Important:** `backend/api/sql/explore.sql` is a copied build artifact, not the source of truth. Changes made only there will be overwritten.

## What To Read Before Editing

### Ingest and schema work

1. [`backend/scraper/README.md`](../backend/scraper/README.md)
2. [`ARCHITECTURE.md`](../ARCHITECTURE.md)
3. The relevant parser or SQL file: `src/bills.rs`, `src/votes.rs`, `src/db.rs`, `schema.sql`

### API behavior

1. [`backend/api/README.md`](../backend/api/README.md)
2. The relevant file in `backend/api/routes/`
3. `backend/api/controllers/db.js`
4. `backend/api/utils/cache.js` if the route is cached

### Frontend behavior

1. [`frontend/README.md`](../frontend/README.md)
2. `frontend/composables/useCongressApi.ts`
3. `frontend/composables/useApiBase.ts`
4. The page or component you plan to touch

### Deployment and operations

1. [`deployment.md`](deployment.md)
2. [`ARCHITECTURE.md`](../ARCHITECTURE.md)
3. The relevant Argo application under `argo/applications/`
4. The synced manifest root under `k8s/netcup-*`

## Common Tasks

| Goal | Usually edit these files |
| --- | --- |
| Add a new bill field to a page | `backend/scraper/src/bills.rs`, `backend/scraper/src/db.rs`, relevant API route, `frontend/types/congress.ts`, relevant page |
| Add a new vote-derived metric | `backend/scraper/src/votes.rs`, maybe `schema.sql`, then API route or explore query, then frontend |
| Add or change an explore query | `backend/scraper/explore.sql`, `backend/api/services/exploreQueries.js`, `frontend/pages/explore.vue` |
| Fix stale API responses | `backend/api/utils/cache.js`, the cached route, Redis config, scraper invalidation flow |
| Fix the wrong API target in a deployed frontend | `frontend/composables/useApiBase.ts`, `frontend/docker-entrypoint.sh`, or the manifest that sets `NUXT_API_SERVER` |
| Change the default API or Redis deployment | `argo/applications/csearch-netcup-core.yaml`, `k8s/netcup-core/` |
| Change the default database deployment | `argo/applications/csearch-netcup-db.yaml`, `k8s/netcup-db/` |
| Change the default scraper deployment | `argo/applications/csearch-netcup-scraper.yaml`, `k8s/netcup-scraper/` |
| Change the test frontend deployment | `argo/applications/csearch-netcup-test-frontend.yaml`, `k8s/netcup-test-frontend/` |

## Direct Development

### API

```bash
cd backend/api
npm install
npm test
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 npm run dev
```

### Frontend

```bash
cd frontend
npm install
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```

### Scraper

```bash
cd backend/scraper
cargo test
cargo run
```

The scraper requires `CONGRESSDIR` and database env vars. See [`backend/scraper/README.md`](../backend/scraper/README.md) for the expected runtime layout and full variable list.

## Generated and Vendored Files

These files should not be edited by hand:

- `backend/api/sql/explore.sql` — copied from `backend/scraper/explore.sql` at build time.
- `backend/scraper/congress/` — vendored Python scraper. Change only when fetch behavior or upstream format changes.

## Logging Overview

The API and scraper both emit structured JSON to stdout. No special log libraries or agents are needed beyond what is already configured.

**API logging** (Pino via Fastify):

- Per-request completion logs with latency and cache status
- Request-scoped error logs
- Search query logging, admin audit logging, and slow-query warnings
- Config in `backend/api/server.js` and `backend/api/app.js`

**Scraper logging** (`log/slog`):

- Per-bill and per-vote ingest logs
- Run summary with processed/skipped/failed counters and duration
- Python subprocess output re-emitted as structured logs
- Config in `backend/scraper/src/main.rs`

**Log shipping** (Fluent Bit):

- Tails `/var/log/containers/*.log` and filters to CSearch workloads
- Ships to the in-cluster collector or directly to S3
- Config and manifests in `k8s/logging/`
- See [`k8s/logging/README.md`](../k8s/logging/README.md) for shipping modes and environment variables

## Debugging Playbooks

### Data is missing from the site

Work left to right through the pipeline:

1. Confirm the scraper downloaded the expected raw files
2. Confirm the normalized data exists in Postgres
3. Confirm the API route returns that data
4. Confirm the frontend calls the expected endpoint
5. If the public site is stale, confirm the static publish ran after the data changed

### Data exists in Postgres but not in the API

Check the route file in `backend/api/routes/`, any route-level cache behavior, and any response shaping in `services/` or route-specific SQL.

### The frontend is talking to the wrong API

The API base resolution order is:

1. `window.__CSEARCH_RUNTIME_CONFIG__.API_SERVER` from `runtime-config.js`
2. Nuxt public runtime config
3. The default value from `frontend/nuxt.config.ts`

If an nginx container uses the wrong API, the fix is usually in `frontend/docker-entrypoint.sh`, the manifest that sets `NUXT_API_SERVER`, or the environment the container started with.

### The scraper says nothing changed when you expected updates

Check whether the source files actually changed, whether the file hash caches already contain the new digests, and whether `RUN_BILLS` or `RUN_VOTES` disabled part of the run.

### Cache invalidation looks wrong

Check whether all API pods point at the same `REDIS_URL`, whether Redis is reachable, whether the scraper actually wrote any new rows before invalidation, and whether the route you are testing is a cached route. See [`caching.md`](caching.md) for the full cache behavior model.

### A change to explore SQL does not show up after deploy

The change was likely made only in `backend/api/sql/explore.sql`. Update `backend/scraper/explore.sql` instead, then rebuild or redeploy the API.

### Logging looks incomplete

Check that workload labels include `app.kubernetes.io/name`, that the Fluent Bit grep filter still matches, that the chosen logging mode has its required env vars set, and that `/root/logs` is writable if using the tiny collector path.

## Things That Commonly Confuse New Contributors

**Old manifests in the repo** — Use `argo/applications/` and the `k8s/netcup-*` directories for the default deployment path. Legacy manifests live under `k8s/archive/legacy/`.

**Multiple frontend deployment shapes** — There are three: local `nuxt dev`, static S3/CloudFront publish, and nginx container in Kubernetes. They resolve the API base URL differently.

**The scraper is both Rust and Python** — Python handles source acquisition, Rust handles normalization and database writes. If raw files are missing, start in the Python side. If normalized data is wrong, start in Rust.

## Data Coverage

| Data type | Range |
| --- | --- |
| Bills | 93rd Congress through current |
| Votes | 101st Congress through current |

The current congress number is computed dynamically from the current year: `(year - 1789) / 2 + 1`.

## First-Day Checklist

1. Read [`README.md`](../README.md)
2. Read the README for the area you expect to touch most
3. Trace one page from UI → API → Postgres → scraper
4. Inspect the default Argo applications in `argo/applications/`
5. Read [`deployment.md`](deployment.md) so the release path is not a black box later
