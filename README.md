# CSearch

Full-stack platform for searching and browsing U.S. congressional bills and votes. Ingests data from GovInfo and congress.gov, normalizes it into Postgres, and serves it through a REST API and static frontend.

## Architecture

```
  GovInfo / congress.gov
          |
    backend/scraper          Go + Python scraper, runs daily via k8s CronJob
          |
       Postgres 15           Partitioned by congress (93rd–current), full-text search
          |
     backend/api             Fastify REST API (Node.js)
          |
       frontend              Nuxt 4 static site (S3 + CloudFront)
```

## Tech Stack

| Layer | Technology |
|---|---|
| Scraper | Go 1.19, Python 3.11 (scrapelib), XML/JSON parsing |
| Database | PostgreSQL 15, partitioned tables, GIN-indexed tsvector search |
| API | Node.js, Fastify 4, Knex query builder, pg driver |
| Frontend | Nuxt 4, Vue 3, Tailwind CSS, static site generation |
| Infra | Docker, Kubernetes, S3, CloudFront |

## Project Structure

```
backend/
  scraper/        Go ingest pipeline + vendored Python scraper
  api/            Fastify REST API
frontend/         Nuxt 4 static site
k8s/              Kubernetes manifests
docker-compose.yml
deploy.sh         Cluster deployment script
.env.prod         Production secrets (not committed)
```

## Data Coverage

- **Bills**: 93rd Congress (1973) through current, all 8 bill types (HR, S, HJRES, SJRES, HCONRES, SCONRES, HRES, SRES)
- **Votes**: 101st Congress (1989) through current, House and Senate
- **Normalized tables**: bills, bill_actions, bill_cosponsors, bill_committees, bill_subjects, votes, vote_members

The current congress number is computed dynamically: `(year - 1789) / 2 + 1`.

## API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/latest/:billtype` | Latest 500 bills by type, sorted by most recent action |
| GET | `/search/:table/:filter?query=` | Full-text search across bills or votes |
| GET | `/bills/:billtype/:congress/:number` | Bill detail with actions, cosponsors, committees, and related votes |
| GET | `/bills/bynumber/:number` | All bill types matching a bill number |
| GET | `/votes/:chamber` | Recent votes by chamber |
| GET | `/explore` | List of pre-built analytical queries |
| GET | `/explore/:query` | Run a specific analytical query |

## Quick Start

### Local dev (Docker Compose)

```bash
docker-compose up --build
```

This starts Postgres, the API, and an nginx proxy serving the frontend:

| Service | URL |
|---|---|
| Frontend | http://localhost:8080 |
| API | http://localhost:3000 |
| Postgres | localhost:5433 |

### Frontend only

```bash
cd frontend
npm install
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```

### API only

```bash
docker-compose up postgres api
# API available at http://localhost:3000
```

## Deployment

### Prerequisites

- Docker with buildx
- AWS CLI configured (for S3/CloudFront)
- kubectl with cluster context
- `.env.prod` populated from `.env.prod.example`

### Frontend

```bash
cd frontend
bash deploy.sh
```

Builds with `nuxt generate`, syncs to S3, and invalidates CloudFront.

### Backend (API + Scraper)

Build and push container images, then restart deployments:

```bash
source .env.prod

# API
cd backend/api
docker buildx build --platform linux/amd64 --push -t "$REGISTRY/csearch-api:latest" .
kubectl rollout restart deployment/csearch-api

# Scraper
cd ../..
docker buildx build --platform linux/amd64 --push -t "$REGISTRY/csearch-updater:latest" -f backend/scraper/Dockerfile .
```

### Full cluster deploy

```bash
bash deploy.sh
```

Applies all Kubernetes manifests (Postgres, API, scraper CronJob) in order.

## Search

Bill and vote search use PostgreSQL full-text search with weighted `tsvector` columns:

- **Bills**: title (A), official title (A), summary (B), sponsor name (C), policy area (C)
- **Votes**: question (A), result (B), vote type (C), chamber (D)

The `bills` table is partitioned by congress number for fast per-congress queries. GIN indexes on all tsvector columns support ranked search via `ts_rank_cd`.

## License

See [LICENSE.txt](LICENSE.txt).
