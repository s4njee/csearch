# CSearch

A monorepo for ingesting, storing, querying, and presenting U.S. congressional bill and vote data.

```
GovInfo + congress.gov
        |
        v
  scraper  -->  PostgreSQL  -->  API  -->  frontend
                     |            ^
                     +-- Redis ---+
```

## Getting Started

**Quick start:**

```bash
# API
cd backend/api && npm install && npm test
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 npm run dev

# Frontend
cd frontend && npm install
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev

# Scraper
cd backend/scraper && cargo test
```

**Reading order for new contributors:**

1. **This file** -- project overview and repo layout
2. **[`docs/engineering-guide.md`](docs/engineering-guide.md)** -- mental model, source-of-truth map, common tasks, debugging
3. **[`docs/deployment.md`](docs/deployment.md)** -- Argo CD flow, useful commands, change checklist
4. **[`docs/caching.md`](docs/caching.md)** -- Redis behavior, invalidation, failure model
5. **[`ARCHITECTURE.md`](ARCHITECTURE.md)** -- full runtime architecture, data flows, component details

Then the README for the area you're changing:
[`backend/scraper/`](backend/scraper/README.md) |
[`backend/api/`](backend/api/README.md) |
[`frontend/`](frontend/README.md)

## Repository Layout

| Path | Description |
| --- | --- |
| `backend/scraper/` | Rust ingest pipeline with vendored Python scraper. Owns schema bootstrap, parsing, hash-based skip logic, and Redis cache invalidation. |
| `backend/api/` | Fastify API with Knex queries, Redis route caching, and Pino logging. |
| `frontend/` | Nuxt 4 app -- static S3/CloudFront publishing, nginx container deploys, and local dev. |
| `argo/` | Argo CD `Application` manifests (deployment control plane). |
| `k8s/` | Kubernetes workload manifests synced by Argo. |
| `k8s/logging/` | Fluent Bit config, DaemonSet, collector, and optional Grafana dashboards. |
| `docs/` | Engineering onboarding and operational docs. |
| `archiver/` | Utility container for archiving the congress data directory. |

## Components

**Scraper** -- Kubernetes CronJob running daily at midnight CT. Fetches bill/vote source files via the vendored Python scraper, skips unchanged files using SHA-256 hashes, and upserts normalized data into Postgres. Covers bills from the 93rd Congress and votes from the 101st onward.

**Database** -- Postgres is the system of record. Schema bootstrapped from `backend/scraper/schema.sql`.

**API** -- Fastify service over Postgres. Serves bill/vote lists and detail, search, member/committee pages, and explore queries. Hot routes cached in Redis (24h TTL).

**Frontend** -- Nuxt 4 static site at csearch.org (S3 + CloudFront). Also supports nginx container deploys for cluster environments like test.csearch.org.

**Logging** -- Structured JSON to stdout. Fluent Bit tails container logs and ships to the in-cluster collector or S3.

## Key Conventions

- Scraper runtime is handwritten Rust under `backend/scraper/src/`.
- `backend/scraper/Cargo.toml` is source of truth for scraper dependencies.
- `backend/scraper/explore.sql` is source of truth for explore queries; `backend/api/sql/explore.sql` is a copied build artifact.
- `backend/scraper/congress/` is vendored upstream code.
- `argo/applications/` is the default deployment entry point.

## License

See [`LICENSE.txt`](LICENSE.txt).
