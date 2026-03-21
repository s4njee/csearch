# CSearch

CSearch is a monorepo for ingesting, storing, querying, and presenting U.S. congressional bill and vote data.

At a high level:

```text
GovInfo + congress.gov
        |
        v
backend/scraper  ->  PostgreSQL  ->  backend/api  ->  frontend
                          |               ^
                          |    Redis      |
                          +---(cache)-----+
```

The repository is organized around three active production projects:

| Project | Path | Primary responsibility |
| --- | --- | --- |
| Scraper | `backend/scraper/` | Fetch raw congress data, normalize it, and upsert it into Postgres |
| API | `backend/api/` | Serve bill, vote, member, committee, and explore data over HTTP |
| Frontend | `frontend/` | Render the public csearch.org experience with Nuxt static generation |

## Read This First

If you are new to the codebase, read the docs in this order:

1. This file for the repo map and day-one workflow
2. [`docs/engineering-guide.md`](docs/engineering-guide.md) for onboarding and common tasks
3. [`ARCHITECTURE.md`](ARCHITECTURE.md) for the runtime and deployment model
4. The project README for the area you are changing:
   - [`backend/scraper/README.md`](backend/scraper/README.md)
   - [`backend/api/README.md`](backend/api/README.md)
   - [`frontend/README.md`](frontend/README.md)

## Repository Map

| Path | What lives here | Notes |
| --- | --- | --- |
| `backend/scraper/` | Go ingest pipeline plus the vendored Python `congress` scraper | Owns schema bootstrap, SQL source, and data normalization |
| `backend/api/` | Fastify API, Knex queries, tests | Serves the frontend and deployment warm-up traffic |
| `frontend/` | Nuxt app, nginx runtime image, deploy scripts | Production is static output on S3 + CloudFront |
| `k8s/` | Active Kubernetes manifests | This is the current source of truth for cluster resources |
| `docs/` | Engineer-facing onboarding docs | Start here if you are learning the repo |
| `archiver/` | Small utility container for archiving the congress data directory | Supporting utility, not part of the main request path |
| `backend/api/k8s/` | Older API-scoped manifests and examples | Useful historical reference, but not the primary deploy path today |
| `updater/` | Currently unused placeholder directory | Safe to ignore unless it becomes active again |

## Folder Structure

This tree is the quickest way to orient yourself in the repo:

```text
csearch-updater-root/
├── README.md
├── ARCHITECTURE.md
├── docs/
│   └── engineering-guide.md
├── backend/
│   ├── scraper/
│   │   ├── main.go
│   │   ├── runtime.go
│   │   ├── bills.go
│   │   ├── votes.go
│   │   ├── hashes.go
│   │   ├── query.sql
│   │   ├── schema.sql
│   │   ├── explore.sql
│   │   ├── csearch/
│   │   └── congress/
│   └── api/
│       ├── app.js
│       ├── server.js
│       ├── controllers/
│       ├── routes/
│       ├── services/
│       ├── utils/
│       ├── test/
│       └── sql/
├── frontend/
│   ├── pages/
│   ├── components/
│   ├── composables/
│   ├── assets/
│   ├── public/
│   ├── nuxt.config.ts
│   ├── deploy.sh
│   ├── Dockerfile.nginx
│   └── Dockerfile.deploy
├── k8s/
│   ├── api/
│   ├── db/
│   ├── frontend/
│   ├── logging/
│   ├── scraper/
│   └── dev/
├── archiver/
├── docker-compose.yml
└── deploy.sh
```

### What The Main Folders Mean

| Folder | Why it exists |
| --- | --- |
| `docs/` | Human-oriented onboarding and engineering documentation |
| `backend/scraper/` | Data ingest pipeline, schema source, and SQL generation inputs |
| `backend/api/` | HTTP API, route handlers, and API tests |
| `frontend/` | Nuxt site, generated-site deploy scripts, and nginx container variants |
| `k8s/` | Active Kubernetes manifests for the current platform |
| `archiver/` | Utility container for archiving congress data on disk |

### Subfolders You Will Use Most Often

| Path | What you usually do there |
| --- | --- |
| `backend/scraper/congress/` | Debug low-level source fetching only when upstream formats or download behavior change |
| `backend/scraper/csearch/` | Read generated query types if helpful, but do not edit by hand |
| `backend/api/routes/` | Add or change endpoints |
| `backend/api/services/` | Shared API-side logic such as explore-query execution |
| `backend/api/test/` | Update or add API coverage |
| `frontend/pages/` | Change route-level UI and page data loading |
| `frontend/components/` | Edit reusable UI building blocks |
| `frontend/composables/` | Change API access and runtime configuration behavior |
| `k8s/frontend/` | Frontend deployments, services, and scheduled publish jobs |
| `k8s/logging/` | Fluent Bit, tiny log collector manifests, and logging notes |
| `k8s/scraper/` | Scraper CronJob and storage configuration |

## System Overview

### Scraper

The scraper runs on a daily Kubernetes CronJob. Each run:

1. Calls the vendored Python scraper to pull bill status XML and vote JSON
2. Walks the downloaded files in Go
3. Skips unchanged files using SHA-256 hash caches
4. Writes normalized records into Postgres

### Database

Postgres is the system of record. The schema is initialized from [`backend/scraper/schema.sql`](backend/scraper/schema.sql), and the scraper is responsible for keeping normalized bill and vote tables populated.

### API

The API reads from Postgres and exposes endpoints for:

- latest bills
- bill detail
- bill search
- recent votes and vote detail
- member and committee pages
- analytical explore queries

### Cache

The API uses Redis as a shared cache in front of Postgres. Responses for the most expensive and frequently-hit read endpoints are serialized to Redis with a 24-hour TTL. All API replicas share the same Redis instance, so a cache hit from one pod is a hit for all — and a manual or automatic invalidation is consistent across the cluster.

**What gets cached**

| Route | Cache key |
| --- | --- |
| `GET /latest/:billtype` | `csearch:latest_bills_<billtype>` |
| `GET /votes/:chamber` | `csearch:latest_votes_<chamber>` |
| `GET /explore/:queryId` | `csearch:explore_<queryId>` |

**Cache invalidation**

The scraper automatically clears all `csearch:*` keys at the end of a run when it has processed at least one bill or vote. This means freshly ingested data is visible on the next API request after the daily CronJob completes.

Cache can also be cleared manually:

```bash
curl -X POST http://localhost:3000/admin/clear-cache \
  -H "Authorization: <SECRET_KEY>"
```

**Cache headers**

Every response from a cached route includes an `X-Cache` header:

- `X-Cache: HIT` — served from Redis
- `X-Cache: MISS` — fetched from Postgres and written to Redis

**Graceful degradation**

If Redis is unavailable, the API continues to serve requests directly from Postgres. Cache operations fail silently — no errors are surfaced to the client.

**Configuration**

| Variable | Default | Notes |
| --- | --- | --- |
| `REDIS_URL` | `redis://localhost:6379` | Set to `redis://csearch-redis:6379` in K8s production |

In K8s the Redis deployment runs `redis:7-alpine` with `--maxmemory 128mb` and `--maxmemory-policy allkeys-lru`. See `k8s/redis/` for the full manifest.

### Frontend

The frontend is a Nuxt 4 app. Production builds are generated statically, uploaded to S3, and served from CloudFront. A separate nginx-based deployment is used for the `mars` development cluster.

The `mars` dev stack also includes a lightweight API deployment from `k8s/dev/api.yaml`. That manifest currently points at the shared in-cluster `postgres` service, deploys a `redis-dev` cache service, and uses the `registry.s8njee.com/csearch-api:redis` image tag for Redis-enabled API testing.

## Quick Start

### Full local stack

```bash
docker-compose up --build
```

This starts:

| Service | URL / host |
| --- | --- |
| Frontend | [http://localhost:8080](http://localhost:8080) |
| API | [http://localhost:3000](http://localhost:3000) |
| Postgres | `localhost:5433` |
| Redis | `localhost:6379` |
| Scraper | Runs as a container in the compose stack |

Notes:

- The frontend proxies API calls through `/api` in local Docker development.
- The scraper container may take a while on the first run because it needs to download and parse source data.

### Frontend only

```bash
cd frontend
npm install
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```

### API only

```bash
docker-compose up postgres api
```

### Scraper only

Use the compose stack if you want the easiest path. If you need to run the scraper directly, see [`backend/scraper/README.md`](backend/scraper/README.md) for the required environment variables and data directory layout.

## Common Tasks

| Task | Start here |
| --- | --- |
| Add a bill or vote field to the system | [`backend/scraper/README.md`](backend/scraper/README.md), then [`backend/api/README.md`](backend/api/README.md), then [`frontend/README.md`](frontend/README.md) |
| Debug missing or stale data | [`docs/engineering-guide.md`](docs/engineering-guide.md) and [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Add or change an explore query | `backend/scraper/explore.sql`, [`backend/api/README.md`](backend/api/README.md), and `frontend/pages/explore.vue` |
| Change a deployment behavior | `deploy.sh`, `frontend/deploy.sh`, and the manifests under `k8s/` |
| Find the live Kubernetes configuration | `k8s/` at the repo root |

## Deployment Summary

### Full platform deploy

```bash
bash deploy.sh
```

The root deploy script:

1. Loads `.env.prod`
2. Builds and pushes the database, API, scraper, and frontend deploy images
3. Applies database and API manifests
4. Applies the scraper CronJob
5. By default applies the tiny in-cluster log collector plus the in-repo Fluent Bit DaemonSet
6. Runs the frontend production deploy script

## Logging

The logging path is intentionally lightweight:

1. the API and scraper write structured JSON to stdout
2. Fluent Bit tails Kubernetes container logs and adds Kubernetes metadata
3. a tiny in-cluster HTTP collector receives newline-delimited JSON from Fluent Bit
4. the collector appends those records into daily `.ndjson` files on the node host path

On the current cluster defaults, those files are written under:

- `/root/logs/csearch/csearch/YYYY-MM-DD.ndjson`

Relevant files:

- [`backend/log-collector/main.go`](/Users/sanjee/Documents/projects/csearch-updater-root/backend/log-collector/main.go)
- [`k8s/logging/fluent-bit-config.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/logging/fluent-bit-config.yaml)
- [`k8s/logging/fluent-bit-daemonset.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/logging/fluent-bit-daemonset.yaml)
- [`k8s/logging/collector-deployment.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/logging/collector-deployment.yaml)

Useful defaults from `.env.prod`:

- `ENABLE_TINY_LOG_COLLECTOR=true`
- `LOG_COLLECTOR_HOSTPATH=/root/logs`

If you want to disable the tiny collector and ship elsewhere, `deploy.sh` still supports the older generic HTTP sink variables:

- `LOG_SHIP_HTTP_HOST`
- `LOG_SHIP_HTTP_PORT`
- `LOG_SHIP_HTTP_URI`

### Frontend production deploy only

```bash
cd frontend
bash deploy.sh
```

### Manual scraper run on the cluster

```bash
kubectl create job csearch-updater-manual-$(date +%s) --from=cronjob/csearch-updater
kubectl logs -f job/<job-name>
```

## A Few Important Conventions

- Treat `k8s/` as the active deployment manifests for the current platform.
- Do not hand-edit `backend/scraper/csearch/*.go`; those files are generated by `sqlc`.
- Treat `backend/scraper/explore.sql` as the source of truth for explore SQL. The root deploy script copies it into the API build context.
- Treat `backend/scraper/congress/` as vendored upstream code. Change it only when the low-level fetch behavior needs to change.

## License

See [`LICENSE.txt`](LICENSE.txt).
