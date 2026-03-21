# Backend API

This service is the read layer for CSearch. It exposes HTTP endpoints over the normalized Postgres data created by the scraper.

Use this README when you need to:

- add or change an endpoint
- understand how the API talks to Postgres
- debug caching, search, or explore-query behavior

## What This Service Owns

The API owns:

- HTTP route definitions
- request validation and response shaping
- search behavior
- explore-query execution
- route-level caching
- structured request logging

The API does not own:

- canonical source data ingestion
- schema bootstrap
- raw scraper downloads

Those belong to `backend/scraper/`.

## Request Flow

For a typical request:

1. Fastify loads plugins and routes from `plugins/` and `routes/`
2. The route validates path or query parameters
3. The route queries Postgres through Knex
4. Some routes use the shared Redis cache in `utils/cache.js`
5. Fastify returns JSON and emits a structured completion log
6. The shared Loki and Grafana stack, managed outside this repo, consumes those logs for dashboards and ad hoc queries

## Key Files

| Path | Purpose |
| --- | --- |
| `app.js` | Global Fastify setup, CORS, compression, rate limiting, request hooks |
| `server.js` | Fastify bootstrap, logger config, graceful shutdown |
| `controllers/db.js` | Knex Postgres connection and pool |
| `routes/` | HTTP route handlers |
| `services/exploreQueries.js` | Parses and runs explore queries from SQL files |
| `utils/cache.js` | Shared Redis cache wrapper used by hot routes |
| `utils/constants.js` | Shared constants such as valid bill types |
| `test/` | Node test runner coverage for routes and services |

## Most Used Files

These are the files engineers most often touch when making normal API changes.

### `server.js`

What it does:

- boots Fastify
- configures JSON logging
- registers the main app
- handles graceful shutdown

Edit this when:

- you need to change global logging behavior
- startup or shutdown behavior needs to change
- server-level Fastify configuration needs to change

### `app.js`

What it does:

- registers global middleware and hooks
- enables CORS and compression
- applies request rate limiting
- logs request completion and request-scoped failures
- loads plugins and routes automatically

Edit this when:

- you need a global Fastify hook
- you want to change compression, rate limiting, or shared app behavior
- multiple routes need common request lifecycle behavior

### `controllers/db.js`

What it does:

- creates the shared Knex connection
- defines the Postgres connection and pool settings

Edit this when:

- database connection settings need to change
- pooling behavior needs tuning
- local and production DB connection defaults need adjustment

### `routes/latestRoute.js`

What it does:

- returns the latest 500 bills for a bill type
- adds committee and cosponsor summary fields
- uses the shared API cache

Edit this when:

- the bill list page needs different fields
- latest bill sort or filtering behavior changes
- cache behavior for latest bills needs to change

### `routes/searchRoute.js`

What it does:

- handles bill search
- supports `relevance` and `date` sorting
- combines full-text search with fuzzy matching
- logs search activity

Edit this when:

- bill search ranking changes
- search validation or filtering changes
- search results need new fields

### `routes/voteRoute.js`

What it does:

- handles vote search
- returns vote detail including member positions

Edit this when:

- vote search behavior changes
- vote detail needs more fields
- member-position output needs reshaping

### `routes/billRoute.js`

What it does:

- returns the full bill detail payload
- joins together the parent bill, actions, cosponsors, votes, and committees

Edit this when:

- the bill detail page needs a new API field
- related bill sub-sections need additional query logic

### `routes/exploreRoute.js`

What it does:

- lists available explore queries
- executes named analytical queries
- caches query responses
- logs slow explore executions

Edit this when:

- explore query execution behavior changes
- explore caching changes
- the API response shape for the explore page changes

### `services/exploreQueries.js`

What it does:

- parses the SQL query pack
- assigns stable IDs to named explore queries
- normalizes parameter handling for special search-style queries

Edit this when:

- you add a new explore query that needs metadata
- an explore query needs parameter parsing or defaults
- query IDs or titles need to stay stable across deploys

### `utils/cache.js`

What it does:

- defines the shared Redis cache used by hot routes
- applies a common key prefix and TTL for cached API responses
- degrades safely when Redis is unavailable so requests still succeed

Edit this when:

- cache TTL changes
- Redis connection behavior changes
- the caching strategy changes globally

### `test/routes/*.test.js`

What it does:

- verifies route behavior and protects against regressions

Edit this when:

- you add or change an endpoint
- response shapes or validation rules change
- you fix a bug and want coverage for it

## Endpoints

### Health and operational endpoints

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/` | Simple root response |
| `GET` | `/health` | Deep health check that also verifies DB connectivity |
| `POST` | `/admin/clear-cache` | Clears the shared Redis cache when called with the correct secret |

### Bills

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/latest/:billtype` | Latest 500 bills for a bill type |
| `GET` | `/search/:table/:filter?query=...` | Bill search, with `table=all` or a bill type and `filter=relevance|date` |
| `GET` | `/bills/:billtype/:congress/:billnumber` | Bill detail with actions, cosponsors, committees, and related votes |
| `GET` | `/bills/bynumber/:number` | All matching bill types for a bill number |

### Votes

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/votes/:chamber` | Recent votes for `house` or `senate` |
| `GET` | `/votes/search?query=...&chamber=...` | Vote search |
| `GET` | `/votes/detail/:voteid` | Single vote with member positions |

### Members and committees

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/members/:bioguide_id` | Member profile, sponsored bills, and recent votes |
| `GET` | `/committees` | Committee list with bill counts |
| `GET` | `/committees/:committee_code` | Committee detail with related bills |

### Explore

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/explore` | Lists available analytical queries |
| `GET` | `/explore/:queryId` | Executes a named analytical query |

## Explore Query Source Of Truth

This is important enough to call out explicitly:

- `backend/scraper/explore.sql` is the source of truth
- `backend/api/sql/explore.sql` is a build artifact copied during the full deploy flow

If you change only `backend/api/sql/explore.sql`, your change can be overwritten the next time `deploy.sh` runs.

When you add or change an explore query, update:

1. `backend/scraper/explore.sql`
2. `services/exploreQueries.js` if query metadata or parameter handling changes
3. the frontend explore page if the UI needs new labels or inputs

## Cache Behavior

The API uses a shared Redis cache in `utils/cache.js`.

Current characteristics:

- 24 hour TTL
- cache keys are prefixed with `csearch:`
- cache is shared across API replicas
- cache survives API pod restarts as long as Redis stays up
- cache reads and writes fail open so Redis outages do not break request handling

Routes that use cache set the `X-Cache` response header to `HIT` or `MISS`.

This matters operationally because cache invalidation now applies across replicas instead of only within one pod.

## Environment Variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `HOST` | No | Bind address, defaults to `0.0.0.0` |
| `PORT` | No | Port, defaults to `3000` |
| `POSTGRESURI` | Yes | Postgres host |
| `DB_PORT` | No | Postgres port, defaults to `5432` |
| `DB_USER` | No | Postgres user, defaults to `postgres` |
| `DB_PASSWORD` | No | Postgres password, defaults to `postgres` |
| `DB_NAME` | No | Database name, defaults to `csearch` |
| `REDIS_URL` | No | Redis connection string, defaults to `redis://localhost:6379` |
| `SECRET_KEY` | For admin endpoint | Secret required by `/admin/clear-cache` |
| `LOG_LEVEL` | No | Fastify / Pino log level |
| `FASTIFY_CLOSE_GRACE_DELAY` | No | Graceful shutdown delay |
| `GOOGLE_CLIENT_ID` | Only if using auth flow | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Only if using auth flow | Google OAuth client secret |

## Local Development

### Easiest path

Run the API with local Postgres through Docker Compose:

```bash
docker-compose up postgres api
```

The API will be available at [http://localhost:3000](http://localhost:3000).

Redis is also started by the compose stack for cached routes.

### Run directly with Node

```bash
cd backend/api
npm install
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 npm run dev
```

This is useful when you want Fastify file watching and you already have Postgres and Redis running.

## Tests

Run the API tests from `backend/api/`:

```bash
npm test
```

Tests use Node's built-in test runner and cover routes, plugins, and explore-query helpers.

## Build And Deploy

### Build the API image

```bash
cd backend/api
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-api:latest" .
```

### Restart the API deployment

```bash
kubectl rollout restart deployment/csearch-api
kubectl rollout status deployment/csearch-api
```

### Full platform deploy

Use the repo root script when the API change also needs the current platform deployment flow:

```bash
bash deploy.sh
```

## How To Make Common Changes

### Add a new endpoint

1. Create or update a file in `routes/`
2. Use `controllers/db.js` for Knex access
3. Add tests under `test/routes/`
4. If the endpoint is expensive and hot, decide whether it needs cache behavior

### Change bill or vote search behavior

Look at:

- `routes/searchRoute.js`
- `routes/voteRoute.js`
- any relevant search indexes or source fields in the database schema

Search behavior is primarily database-driven, so changes often need coordination with the scraper-owned schema or source data.

### Add a field to an existing response

1. Confirm the field exists in Postgres
2. Update the relevant Knex query in `routes/`
3. Add or update tests
4. Update the frontend types and UI if the field is consumed there

## Troubleshooting

### The API boots but `/health` fails

That usually means Fastify started but Postgres is unreachable. Check the DB environment variables and whether the database is actually accepting connections.

### An explore query works locally but not after deploy

Confirm the change was made in `backend/scraper/explore.sql`, not just in `backend/api/sql/explore.sql`.

### Cache clear appears inconsistent across replicas

That is no longer expected with the Redis-backed cache. If cache invalidation looks inconsistent, check whether all API pods point at the same `REDIS_URL` and whether Redis is reachable.

## Notes On Repo Layout

- The live Kubernetes manifests are under the repo root `k8s/`, not under `backend/api/k8s/`.
- The files in `backend/api/k8s/` are older service-local manifests and examples. Use them as reference only unless you are intentionally reviving that path.
