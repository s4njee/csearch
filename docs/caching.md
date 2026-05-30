# Caching Guide

The API uses a shared Redis cache for hot routes. This document covers the cache behavior, invalidation model, failure characteristics, and operational commands.

## Cache Characteristics

- 24-hour TTL
- Key prefix: `csearch:`
- Shared across all API replicas
- Survives API pod restarts while Redis stays available
- Fails open — Redis outages do not break request handling

The implementation lives in
[`backend/api/src/csearch_api/cache.py`](../backend/api/src/csearch_api/cache.py).

## Cached Routes

| Route | Cache key | Response header |
| --- | --- | --- |
| `GET /latest/{billtype}` | `csearch:latest_bills_<billtype>` | `X-Cache: HIT` or `MISS` |
| `GET /votes/{chamber}` | `csearch:latest_votes_<chamber>` | `X-Cache: HIT` or `MISS` |
| `GET /explore/{query_id}` | `csearch:explore_<query_id>_<query-string>` | `X-Cache: HIT` or `MISS` |
| `GET /committees` | `csearch:committees_all` | `X-Cache: HIT` or `MISS` |
| `GET /committees/{committee_code}` | `csearch:committee_<committee_code>` | `X-Cache: HIT` or `MISS` |
| `GET /representatives/{zipcode}` | `csearch:representatives_<zipcode>` | `X-Cache: HIT` or `MISS` |

## Invalidation

### Scraper-driven invalidation

The scraper clears all `csearch:*` keys after a run that wrote at least one changed bill or vote row. This happens at the end of the ingest pipeline in `backend/scraper/src/main.rs` and `backend/scraper/src/redis_cache.rs`.

### Manual invalidation

There is no active public cache-clear route in the FastAPI service. Manual
clears should be done from Redis or by running a scraper/data-pipeline job that
writes changed rows.

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
POSTGRESURI=localhost DB_PORT=5433 REDIS_URL=redis://localhost:6379 \
  uvicorn csearch_api.main:app --reload --port 3000
```

## Key Files

| File | Purpose |
| --- | --- |
| `backend/api/src/csearch_api/cache.py` | Redis cache client and operations |
| `backend/api/src/csearch_api/routes/bills.py` | Latest bill caching |
| `backend/api/src/csearch_api/routes/votes.py` | Latest vote caching |
| `backend/api/src/csearch_api/routes/explore.py` | Explore query caching |
| `backend/api/src/csearch_api/routes/committees.py` | Committee caching |
| `backend/api/src/csearch_api/routes/representatives.py` | ZIP representative lookup caching |
| `backend/scraper/src/main.rs` | Scraper-triggered invalidation |
| `backend/scraper/src/redis_cache.rs` | Redis connection and key clearing |

## Common Issues

**Cache invalidation looks inconsistent** — Check that all API pods point at the same `REDIS_URL`, that Redis is reachable, and that the scraper actually changed rows before attempting invalidation.

**Scraper finished but cached data is stale** — The scraper may have skipped unchanged files (hashes matched), or the specific route you're testing may not be one of the cached routes listed above.

**Cache clear only affects some pods** — This should not happen with the Redis-backed cache since it is shared. If it does, verify `REDIS_URL` is consistent across all API pod environments.
