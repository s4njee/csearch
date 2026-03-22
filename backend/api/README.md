# Backend API

This service is the read layer for CSearch. It exposes HTTP endpoints over the normalized Postgres data produced by the scraper.

Use this README when you need to:

- add or change an endpoint
- understand how the API talks to Postgres
- debug Redis caching, search, or explore-query behavior

## What This Service Owns

The API owns:

- HTTP route definitions
- request validation and response shaping
- search behavior
- explore-query execution
- route-level Redis caching
- structured request logging

The API does not own:

- canonical source data ingestion
- schema bootstrap
- raw scraper downloads

Those belong to `backend/scraper/`.

## Request Flow

For a typical request:

1. Fastify loads plugins and routes from `plugins/` and `routes/`
2. the route validates path or query parameters
3. the route queries Postgres through Knex
4. some routes consult Redis through `utils/cache.js`
5. Fastify returns JSON and emits a structured completion log

Logs go to stdout. Shipping and storage are handled by the Kubernetes logging path.

## Key Files

| Path | Purpose |
| --- | --- |
| `app.js` | global Fastify setup, CORS, compression, rate limiting, request hooks |
| `server.js` | Fastify bootstrap, logger config, graceful shutdown |
| `controllers/db.js` | Knex Postgres connection and pool |
| `routes/` | HTTP route handlers |
| `services/exploreQueries.js` | parses and runs explore queries from SQL files |
| `utils/cache.js` | shared Redis cache wrapper used by hot routes |
| `utils/constants.js` | shared constants such as valid bill types |
| `test/` | Node test coverage for routes and helpers |

## Common Edit Points

| File | Edit this when |
| --- | --- |
| `app.js` | you need a global hook, shared lifecycle behavior, or app-wide Fastify config |
| `server.js` | startup, shutdown, or logger config needs to change |
| `controllers/db.js` | DB connection settings or pool behavior need tuning |
| `routes/latestRoute.js` | latest bill list fields, sorting, or cache behavior changes |
| `routes/searchRoute.js` | bill search ranking, validation, or result shaping changes |
| `routes/voteRoute.js` | vote search or vote detail payload changes |
| `routes/billRoute.js` | bill detail payload changes |
| `routes/exploreRoute.js` | explore execution or caching changes |
| `utils/cache.js` | Redis TTL, error handling, or key behavior changes |

## Endpoints

### Health and operational endpoints

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/` | simple root response |
| `GET` | `/health` | deep health check that verifies DB connectivity |
| `POST` | `/admin/clear-cache` | clears shared Redis keys when called with the correct secret |

### Bills

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/latest/:billtype` | latest 500 bills for a bill type |
| `GET` | `/search/:table/:filter?query=...` | bill search, with `table=all` or a bill type and `filter=relevance|date` |
| `GET` | `/bills/:billtype/:congress/:billnumber` | bill detail with actions, cosponsors, committees, and related votes |
| `GET` | `/bills/bynumber/:number` | all matching bill types for a bill number |

### Votes

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/votes/:chamber` | recent votes for `house` or `senate` |
| `GET` | `/votes/search?query=...&chamber=...` | vote search |
| `GET` | `/votes/detail/:voteid` | single vote with member positions |

### Members and committees

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/members/:bioguide_id` | member profile, sponsored bills, and recent votes |
| `GET` | `/committees` | committee list with bill counts |
| `GET` | `/committees/:committee_code` | committee detail with related bills |

### Explore

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/explore` | lists available analytical queries |
| `GET` | `/explore/:queryId` | executes a named analytical query |

### Auth and vote-tracking

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/login` | login bootstrap route used by the current auth flow |
| `POST` | `/addVote` | authenticated vote-tracking action |
| `POST` | `/removeVote` | authenticated vote-tracking action |

## Explore Query Source Of Truth

- `backend/scraper/explore.sql` is the source of truth
- `backend/api/sql/explore.sql` is a copied build artifact

If you change only `backend/api/sql/explore.sql`, your change can be overwritten the next time the API image is rebuilt.

## Cache Behavior

The API uses a shared Redis cache in `utils/cache.js`.

Current characteristics:

- 24 hour TTL
- keys prefixed with `csearch:`
- shared across API replicas
- survives API pod restarts while Redis stays up
- reads and writes fail open so Redis outages do not break request handling

Routes that use the cache set the `X-Cache` response header to `HIT` or `MISS`.

Current cached routes:

- `GET /latest/:billtype`
- `GET /votes/:chamber`
- `GET /explore/:queryId`

## Environment Variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `HOST` | No | bind address, defaults to `0.0.0.0` |
| `PORT` | No | port, defaults to `3000` |
| `POSTGRESURI` | Yes | Postgres host |
| `DB_PORT` | No | Postgres port, defaults to `5432` |
| `DB_USER` | No | Postgres user, defaults to `postgres` |
| `DB_PASSWORD` | No | Postgres password, defaults to `postgres` |
| `DB_NAME` | No | database name, defaults to `csearch` |
| `REDIS_URL` | No | Redis connection string, defaults to `redis://localhost:6379` |
| `SECRET_KEY` | For admin endpoint | secret required by `/admin/clear-cache` |
| `LOG_LEVEL` | No | Fastify or Pino log level |
| `FASTIFY_CLOSE_GRACE_DELAY` | No | graceful shutdown delay |
| `GOOGLE_CLIENT_ID` | Only if using auth flow | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Only if using auth flow | Google OAuth client secret |

## Direct Development

Run directly with Node:

```bash
cd backend/api
npm install
npm test
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 npm run dev
```

This assumes you already have Postgres and Redis available.

## Deployment

Argo CD is the default deployment path for the API.

Default deployment entry points:

- [`argo/applications/csearch-netcup-core.yaml`](../../argo/applications/csearch-netcup-core.yaml)
- [`k8s/netcup-core/api.yaml`](../../k8s/netcup-core/api.yaml)
- [`k8s/netcup-core/kustomization.yaml`](../../k8s/netcup-core/kustomization.yaml)

### Build the API image directly

Run this from the repo root so you can sync the explore SQL source into the API build context:

```bash
source .env.prod
mkdir -p backend/api/sql
cp backend/scraper/explore.sql backend/api/sql/explore.sql

cd backend/api
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-api:latest" .
```

## How To Make Common Changes

### Add a new endpoint

1. create or update a file in `routes/`
2. use `controllers/db.js` for Knex access
3. add tests under `test/routes/`
4. decide whether the endpoint needs cache behavior

### Change bill or vote search behavior

Look at:

- `routes/searchRoute.js`
- `routes/voteRoute.js`
- any relevant search indexes or source fields in the database schema

### Add a field to an existing response

1. confirm the field exists in Postgres
2. update the relevant route query
3. add or update tests
4. update frontend types and UI if the field is consumed there

## Troubleshooting

### The API boots but `/health` fails

That usually means Fastify started but Postgres is unreachable. Check the DB env vars and whether the database is accepting connections.

### An explore query works locally but not after deploy

Confirm the change was made in `backend/scraper/explore.sql`, not just in `backend/api/sql/explore.sql`.

### Cache clear appears inconsistent

That is not expected with the Redis-backed cache. Check whether all API pods point at the same `REDIS_URL` and whether Redis is reachable.

### Logs are missing from the central shipper

Remember that the app only writes to stdout. If logs are missing from collectors or dashboards, the problem is usually in the Kubernetes logging path under `k8s/logging/`, not in the request handlers.

## Repo Layout Note

- the active deployment manifests are under the repo root `k8s/`
- the active deployment entry points are under `argo/applications/`
- `backend/api/k8s/` is older service-local material and should be treated as reference only
