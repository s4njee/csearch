# CSearch Platform Architecture

This document explains how the CSearch platform behaves at runtime and how its main pieces fit together.

If you are looking for an onboarding path, start with [`README.md`](README.md) and [`docs/engineering-guide.md`](docs/engineering-guide.md) first.

## System Goals

The platform is optimized around a simple pattern:

1. Pull authoritative congressional data from public sources
2. Normalize it once into Postgres
3. Serve read-heavy traffic cheaply and quickly from an API and static frontend

The codebase is organized to match those goals:

| Layer | Runtime component | Main code |
| --- | --- | --- |
| Source acquisition | Python scraper subprocess | `backend/scraper/congress/` |
| Normalization and ingest | Go updater | `backend/scraper/` |
| Storage | PostgreSQL 15 | `k8s/db/`, `backend/scraper/schema.sql` |
| Read API | Fastify deployment | `backend/api/` |
| Web experience | Nuxt static site and nginx container variants | `frontend/` |

## End-To-End Data Flow

```text
GovInfo / congress.gov
        |
        v
vendored Python congress scraper
        |
        v
Go updater parses XML/JSON and upserts Postgres
        |
        v
Fastify API reads Postgres and caches hot responses in memory
        |
        v
Nuxt frontend consumes the API during static generation and in the browser
```

### Step 1: Fetch raw data

The scraper uses the vendored `unitedstates/congress` Python project to download:

- bill status XML from GovInfo
- vote JSON from congress.gov / related data sources

The Go updater shells out to that Python code instead of reimplementing the network layer. That split keeps upstream fetch behavior available while centralizing CSearch-specific ingest logic in Go.

### Step 2: Parse and normalize

After the raw files are available on disk, the Go updater:

1. Scans supported congress ranges
2. Computes SHA-256 hashes for candidate files
3. Skips unchanged files using persisted hash caches
4. Parses changed files into normalized bill and vote structures
5. Writes the normalized rows into Postgres

The write path is bill-level or vote-level transactional so parent and child records stay consistent.

### Step 3: Serve API traffic

The Fastify API reads directly from Postgres. It does not own the canonical data model; it owns:

- HTTP contracts
- search and filtering behavior
- route-level caching
- structured request logging

Several heavy or popular endpoints cache responses in-process with an LRU cache.

### Step 4: Generate and serve the frontend

The frontend has two different runtime shapes:

- Production website: statically generated output uploaded to S3 and served by CloudFront
- Cluster-hosted frontend: nginx container serving generated output with the API origin injected at runtime

That split is important because a change that affects `nuxt generate` does not necessarily affect the nginx runtime behavior in the same way.

## Runtime Topology

### Scraper

The scraper runs as the `csearch-updater` CronJob defined in [`k8s/scraper/cronjob.yaml`](k8s/scraper/cronjob.yaml).

Current schedule:

- Time zone: `America/Chicago`
- Cron: `0 0 * * *`
- Meaning: every day at midnight Central Time

Important runtime details:

- `RUN_BILLS` and `RUN_VOTES` can independently disable bill or vote ingest
- raw data and hash caches are stored on host-mounted paths under `/root/congress`
- the updater waits for Postgres before it starts

### Database

Postgres runs as a single StatefulSet with a persistent volume claim. Schema bootstrap comes from [`backend/scraper/schema.sql`](backend/scraper/schema.sql), which is mounted into the database container on first initialization.

The database is the source of truth for:

- bills
- bill actions
- bill cosponsors
- bill committees
- bill subjects
- votes
- vote members
- committees

### API

The API runs as the `csearch-api` Deployment defined in [`k8s/api/deployment.yaml`](k8s/api/deployment.yaml).

Important runtime details:

- 2 replicas by default
- health checks hit `/health`
- Knex connection pooling limits database connection pressure
- logs are emitted as JSON to stdout

### Frontend

There are three frontend execution patterns in the repo:

| Pattern | Purpose | Main files |
| --- | --- | --- |
| Local `nuxt dev` | developer workflow | `frontend/package.json`, `frontend/nuxt.config.ts` |
| Production static deploy | public website on S3 + CloudFront | `frontend/deploy.sh` |
| nginx container | cluster-hosted frontend builds | `frontend/Dockerfile.nginx`, `k8s/frontend/*.yaml` |

There is also a deployer CronJob in [`k8s/frontend/deploy-cronjob.yaml`](k8s/frontend/deploy-cronjob.yaml) that uses the deploy-container image to rebuild and publish the static frontend on a schedule.

Current deployer schedule:

- Time zone: `America/Chicago`
- Cron: `0 1 * * *`
- Meaning: every day at 1:00 AM Central Time

## Data Coverage

The supported data ranges are encoded in the scraper:

| Data type | Range |
| --- | --- |
| Bills | 93rd Congress through current |
| Votes | 101st Congress through current |

The current congress number is computed dynamically from the calendar year.

## Storage Layout

The scraper runtime expects a root directory with this shape:

```text
<CONGRESSDIR>/
  congress/   # vendored Python scraper + downloaded raw source files
  data/       # hash caches used by the Go updater
```

Within that runtime:

- bill files are read from `congress/data/<congress>/bills/...`
- vote files are read from `congress/data/<congress>/votes/...`
- bill hash cache is stored at `data/fileHashes.gob`
- vote hash cache is stored at `data/voteHashes.gob`

This distinction matters because raw source files and ingest bookkeeping do not live in the same subdirectory.

## Caching And Freshness

### API cache

The API uses an in-process LRU cache for selected routes such as:

- latest bills
- latest votes
- explore queries

Characteristics:

- cache is per API pod, not shared across pods
- TTL is 24 hours
- cache resets when pods restart

### Frontend freshness

Frontend freshness is tied to static generation. A newly completed scraper run does not automatically update the public site until the frontend deploy flow runs.

The deploy-container flow currently refreshes API pods before generating the site:

1. restart the `csearch-api` deployment
2. wait for healthy API pods
3. run `nuxt generate`
4. sync `.output/public` to S3
5. invalidate CloudFront

That means API cache freshness and frontend freshness are operationally linked.

## Search And Explore

### Search

Search is implemented in Postgres and exposed by the API. Bills and votes use weighted full-text search plus fuzzy matching for short result lists.

### Explore queries

Explore queries are defined in [`backend/scraper/explore.sql`](backend/scraper/explore.sql) and parsed by the API at runtime through [`backend/api/services/exploreQueries.js`](backend/api/services/exploreQueries.js).

Important detail:

- `backend/scraper/explore.sql` is the source of truth
- the root deploy script copies it into `backend/api/sql/explore.sql` during the API image build

## Logging And Observability

The platform uses stdout-first logging so Kubernetes can collect logs without extra application-side logging infrastructure.

### Scraper logging

- JSON logs via Go `log/slog`
- Python subprocess stdout and stderr are re-emitted as structured log lines
- run summaries include counts for processed, skipped, and failed items

### API logging

- JSON logs via Fastify / Pino
- one completion line per request with response time, status, route, and cache status
- errors are logged in request context

### Shipping

If `LOG_SHIP_HTTP_HOST` is configured, the root deployment flow applies a Fluent Bit DaemonSet from `k8s/logging/`.

## Ownership Boundaries

These boundaries reduce confusion when making changes:

- The scraper owns how source data becomes normalized rows.
- The API owns HTTP shapes and route-level query behavior.
- The frontend owns presentation and client/runtime API resolution.
- The top-level `k8s/` directory owns the live cluster definition.

## Common Failure Modes

### The scraper ran, but the site still shows old data

Possible causes:

- the frontend deploy flow has not run yet
- API pods still serve old in-memory cache
- the scraper skipped files because their hashes did not change

### The frontend works locally but fails in a deployed nginx container

Common cause:

- the runtime-injected `NUXT_API_SERVER` differs from the build-time Nuxt default

Check:

- `frontend/docker-entrypoint.sh`
- `frontend/composables/useApiBase.ts`
- the manifest or environment that sets `NUXT_API_SERVER`

### A change to explore SQL does not appear in production

Common cause:

- the change was made only to `backend/api/sql/explore.sql` and not to `backend/scraper/explore.sql`

## Deployment Boundaries

There are two deploy scripts engineers should understand:

| Script | Purpose |
| --- | --- |
| `deploy.sh` | Full platform deploy for images, manifests, and frontend production publish |
| `frontend/deploy.sh` | Frontend-only static generation and S3 + CloudFront publish |

Understanding those two scripts usually answers most “how does production actually update?” questions.
