# Caching Guide

The API uses a shared Redis cache for hot routes. This document covers the cache behavior, invalidation model, failure characteristics, and operational commands.

## Cache Characteristics

- 24-hour TTL
- Key prefix: `csearch:`
- Shared across all API replicas
- Survives API pod restarts while Redis stays available
- Fails open — Redis outages do not break request handling

The implementation lives in [`backend/api/utils/cache.js`](../backend/api/utils/cache.js).

## Cached Routes

| Route | Cache key | Response header |
| --- | --- | --- |
| `GET /latest/:billtype` | `csearch:latest_bills_<billtype>` | `X-Cache: HIT` or `MISS` |
| `GET /votes/:chamber` | `csearch:latest_votes_<chamber>` | `X-Cache: HIT` or `MISS` |
| `GET /explore/:queryId` | `csearch:explore_<queryId>` | `X-Cache: HIT` or `MISS` |

## Invalidation

### Scraper-driven invalidation

The scraper clears all `csearch:*` keys after a run that wrote at least one changed bill or vote row. This happens at the end of the ingest pipeline in `backend/scraper/main.go` and `backend/scraper/runtime.go`.

### Manual invalidation

The API exposes a manual cache clear endpoint:

```text
POST /admin/clear-cache
Authorization: <SECRET_KEY>
```

This clears all shared Redis keys. The endpoint is defined in `backend/api/routes/adminRoute.js`.

## Failure Model

Redis is intentionally non-critical. If Redis is unavailable:

- Cache reads return misses
- Cache writes are silently skipped
- All requests fall through to Postgres
- The API continues serving traffic normally

Cache methods swallow operational errors and return safe fallbacks. This is by design.

## Kubernetes Deployment

The default Redis deployment is at `k8s/netcup-core/redis.yaml`, synced by the `csearch-netcup-core` Argo application.

Current Redis configuration:

- Image: `redis:7-alpine`
- `--maxmemory 128mb`
- `--maxmemory-policy allkeys-lru`

## Useful Commands

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

## Local Development

For direct local runs, the default Redis connection string is `redis://localhost:6379`:

```bash
cd backend/api
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 npm run dev
```

## Key Files

| File | Purpose |
| --- | --- |
| `backend/api/utils/cache.js` | Redis cache client and operations |
| `backend/api/routes/latestRoute.js` | Latest bill caching |
| `backend/api/routes/latestVote.js` | Latest vote caching |
| `backend/api/routes/exploreRoute.js` | Explore query caching |
| `backend/api/routes/adminRoute.js` | Manual cache clear endpoint |
| `backend/scraper/main.go` | Scraper-triggered invalidation |
| `backend/scraper/runtime.go` | Redis connection and key clearing |

## Common Issues

**Cache invalidation looks inconsistent** — Check that all API pods point at the same `REDIS_URL`, that Redis is reachable, and that the scraper actually changed rows before attempting invalidation.

**Scraper finished but cached data is stale** — The scraper may have skipped unchanged files (hashes matched), or the specific route you're testing may not be one of the cached routes listed above.

**Cache clear only affects some pods** — This should not happen with the Redis-backed cache since it is shared. If it does, verify `REDIS_URL` is consistent across all API pod environments.
