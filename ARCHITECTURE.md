# CSearch Platform Architecture

This document describes the runtime model of CSearch with Argo CD as the default deployment strategy.

For onboarding, start with [`README.md`](README.md), [`docs/engineering-guide.md`](docs/engineering-guide.md), and [`docs/deployment.md`](docs/deployment.md) first.

## Platform At A Glance

| Layer | Runtime role | Main code or manifests |
| --- | --- | --- |
| Source acquisition | Vendored Python scraper downloads raw bill and vote data | `backend/scraper/congress/` |
| Normalize and ingest | Go updater parses raw files and writes normalized rows | `backend/scraper/` |
| Storage | PostgreSQL stores canonical bill and vote data | `backend/scraper/schema.sql`, `k8s/netcup-db/` |
| Read API | Fastify serves bills, votes, search, and explore results | `backend/api/`, `k8s/netcup-core/api.yaml` |
| Cache | Redis stores shared API responses for hot routes | `backend/api/utils/cache.js`, `k8s/netcup-core/redis.yaml` |
| Web experience | Nuxt powers the public site and frontend container variants | `frontend/`, `k8s/netcup-test-frontend/` |
| Deployment control plane | Argo CD syncs Git-managed applications | `argo/applications/` |
| Logging | Fluent Bit ships API and scraper stdout to the collector or S3 | `k8s/logging/` |

## Core Flows

### Ingest flow

```text
GovInfo + congress.gov
        |
        v
vendored Python congress scraper
        |
        v
Go updater parses XML/JSON and upserts Postgres
        |
        v
Redis cache invalidation when rows changed
```

Important details:

- bills are processed from the 93rd Congress through current
- votes are processed from the 101st Congress through current
- unchanged files are skipped using persisted SHA-256 hash caches
- bills and votes can be toggled independently with `RUN_BILLS` and `RUN_VOTES`

### Read flow

```text
browser or static generation
        |
        v
Nuxt frontend
        |
        v
Fastify API
        |
        +--> Redis for hot-route cache hits
        |
        v
Postgres
```

Important details:

- the API reads canonical data from Postgres
- hot routes cache JSON responses in Redis with a 24-hour TTL
- if Redis is unavailable, the API falls back to Postgres

## Argo-Managed Runtime Components

### Database

The default database deployment path is [`k8s/netcup-db/`](k8s/netcup-db/), synced by [`argo/applications/csearch-netcup-db.yaml`](argo/applications/csearch-netcup-db.yaml).

This app manages:

- the `postgres-config` ConfigMap
- the `postgres-schema` generated ConfigMap
- the `postgres` StatefulSet
- the `postgres` and `postgres-headless` services

### Core API and Redis

The default API and Redis deployment path is [`k8s/netcup-core/`](k8s/netcup-core/), synced by [`argo/applications/csearch-netcup-core.yaml`](argo/applications/csearch-netcup-core.yaml).

This app manages:

- the `csearch-api` Deployment and Service
- the `csearch-redis` Deployment and Service
- the `api.csearch.org` ingress

Important runtime details:

- API health checks use `GET /health` and verify DB connectivity
- the API logs as structured JSON to stdout
- the API uses shared Redis caching, not per-pod in-memory caching

### Scraper

The default scraper deployment path is [`k8s/netcup-scraper/`](k8s/netcup-scraper/), synced by [`argo/applications/csearch-netcup-scraper.yaml`](argo/applications/csearch-netcup-scraper.yaml).

Current schedule:

- time zone: `America/Chicago`
- cron: `0 0 * * *`
- meaning: every day at midnight Central Time

Important runtime details:

- `CONGRESSDIR` points at a runtime root with both `congress/` and `data/`
- the CronJob mounts `/root/congress` into the container
- the scraper clears `csearch:*` Redis keys after successful writes

### Frontend

The repo has two current frontend deployment shapes:

| Mode | Purpose | Main files |
| --- | --- | --- |
| Public static publish | public site on S3 + CloudFront | `frontend/deploy.sh` |
| Argo-managed nginx frontend | cluster-hosted frontend for `test.csearch.org` | `k8s/netcup-test-frontend/`, `argo/applications/csearch-netcup-test-frontend.yaml` |

There is also a deploy-container path for scheduled static publishing:

- image: `frontend/Dockerfile.deploy`
- runtime script: `frontend/deploy-container.sh`
- CronJob manifest: `k8s/frontend/deploy-cronjob.yaml`

### Logging

The current logging path is repo-owned and stdout-first:

1. API and scraper write structured JSON to stdout
2. Fluent Bit tails Kubernetes container logs
3. Fluent Bit filters to CSearch workloads
4. Fluent Bit ships records either:
   - to the tiny in-cluster HTTP collector
   - directly to S3

Grafana and Loki dashboards in `k8s/logging/dashboards/` are optional assets, not the default deployment path.

## Deployment Model

Argo CD is the default deployment strategy.

Current Argo applications:

| Application | Git path | Sync wave |
| --- | --- | --- |
| `csearch-netcup-db` | `k8s/netcup-db` | `-10` |
| `csearch-netcup-core` | `k8s/netcup-core` | `0` |
| `csearch-netcup-scraper` | `k8s/netcup-scraper` | `10` |
| `csearch-netcup-test-frontend` | `k8s/netcup-test-frontend` | default |

Important details:

- Argo syncs from Git state, not from registry changes alone
- all current netcup Argo applications point at `targetRevision: codex/claude`

## Data Coverage And Storage Layout

### Congress coverage

| Data type | Range |
| --- | --- |
| Bills | 93rd Congress through current |
| Votes | 101st Congress through current |

The current congress number is computed dynamically from the current year.

### Scraper runtime layout

The scraper expects this layout under `CONGRESSDIR`:

```text
<CONGRESSDIR>/
  congress/
    run.py
    data/
      <congress>/
        bills/
        votes/
  data/
    fileHashes.gob
    voteHashes.gob
```

Important distinction:

- raw downloaded source data lives under `congress/data/...`
- ingest bookkeeping lives under `data/...`

## Cache And Freshness

### Redis cache

The API caches selected routes in Redis.

Current characteristics:

- 24 hour TTL
- key prefix `csearch:`
- shared across API replicas
- survives API pod restarts while Redis stays available
- fails open when Redis is unavailable

Current cached routes:

| Route | Cache key |
| --- | --- |
| `GET /latest/:billtype` | `csearch:latest_bills_<billtype>` |
| `GET /votes/:chamber` | `csearch:latest_votes_<chamber>` |
| `GET /explore/:queryId` | `csearch:explore_<queryId>` |

### Frontend freshness

Frontend freshness depends on which frontend path you care about:

- the public site updates when the static publish flow runs
- the Argo-managed frontend updates when its image or manifest changes in Git
- a completed scraper run does not automatically refresh the public static site

## Sources Of Truth That Matter

| Concern | Source of truth |
| --- | --- |
| Database schema bootstrap | `backend/scraper/schema.sql` |
| Scraper SQL input for generated Go code | `backend/scraper/query.sql` |
| Explore SQL | `backend/scraper/explore.sql` |
| API cache implementation | `backend/api/utils/cache.js` |
| Default deployment entry points | `argo/applications/` |
| Default workload manifests | `k8s/netcup-db/`, `k8s/netcup-core/`, `k8s/netcup-scraper/`, `k8s/netcup-test-frontend/` |

## Common Failure Modes

### The scraper finished but the public site still looks old

Possible causes:

- the static frontend publish has not run yet
- the scraper skipped unchanged files because their hashes matched
- the API cache has not yet been refreshed by the next request path you are testing

### A change to explore SQL does not show up after deploy

Common cause:

- the change was made only to `backend/api/sql/explore.sql`

Fix:

- update `backend/scraper/explore.sql`, then rebuild or redeploy the API path that copies it

### Cache invalidation looks inconsistent

That usually means one of these:

- API pods are not pointing at the same `REDIS_URL`
- Redis is unavailable
- the scraper completed without actually changing any bill or vote rows

### Logging looks incomplete

Check:

- workload labels include `app.kubernetes.io/name`
- the Fluent Bit grep filter still matches the workload names
- the chosen logging mode has the required env vars set
- `/root/logs` is writable if you are using the tiny collector path
