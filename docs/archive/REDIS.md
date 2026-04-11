# Redis Cache Notes

This file documents the current Redis-backed cache used by the API.

The earlier migration plan is complete enough that the important thing now is the runtime behavior, not the step-by-step rewrite plan.

## Status

Redis is now the active cache backend for the API.

Current characteristics:

- 24 hour TTL
- key prefix `csearch:`
- shared across API replicas
- survives API pod restarts while Redis stays available
- fails open when Redis is unavailable

The implementation lives in [`../../backend/api/utils/cache.js`](../../backend/api/utils/cache.js).

## Cached Routes

| Route | Cache key |
| --- | --- |
| `GET /latest/:billtype` | `csearch:latest_bills_<billtype>` |
| `GET /votes/:chamber` | `csearch:latest_votes_<chamber>` |
| `GET /explore/:queryId` | `csearch:explore_<queryId>` |

Cached routes set `X-Cache` to `HIT` or `MISS`.

## Invalidation

There are two invalidation paths:

### Scraper-driven invalidation

The scraper clears `csearch:*` keys after a run that wrote at least one changed bill or vote.

Relevant files:

- `backend/scraper/main.go`
- `backend/scraper/runtime.go`

### Manual invalidation

The API exposes:

```text
POST /admin/clear-cache
```

This route requires `Authorization: <SECRET_KEY>` and clears the shared Redis keys.

Relevant file:

- `backend/api/routes/adminRoute.js`

## Failure Model

Redis is intentionally non-critical.

If Redis is unavailable:

- cache reads return misses
- cache writes are skipped
- requests still fall through to Postgres
- the API should continue serving traffic

This is why cache methods swallow operational errors and return safe fallbacks.

## Kubernetes Paths

The default Redis deployment path is:

| Path | Purpose |
| --- | --- |
| `k8s/netcup-core/redis.yaml` | Argo-managed Redis for the default cluster deployment |

The active manifests use `redis:7-alpine` with:

- `--maxmemory 128mb`
- `--maxmemory-policy allkeys-lru`

## Direct Development

For direct local runs, the default connection string is:

```text
redis://localhost:6379
```

Example direct API run:

```bash
cd backend/api
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 npm run dev
```

## Useful Checks

Inspect cache headers:

```bash
curl -I http://localhost:3000/latest/hr
```

Clear cache manually:

```bash
curl -X POST http://localhost:3000/admin/clear-cache \
  -H "Authorization: <SECRET_KEY>"
```

Verify Redis connectivity from Kubernetes:

```bash
kubectl exec deployment/csearch-redis -- redis-cli ping
```

## Key Files

| File | Purpose |
| --- | --- |
| `backend/api/utils/cache.js` | Redis cache client and cache operations |
| `backend/api/routes/latestRoute.js` | latest bill caching |
| `backend/api/routes/latestVote.js` | latest vote caching |
| `backend/api/routes/exploreRoute.js` | explore caching |
| `backend/api/routes/adminRoute.js` | manual cache clear endpoint |
| `backend/scraper/main.go` | scraper-triggered invalidation |
