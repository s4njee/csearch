# csearch-api-cache

KV-backed stale-while-revalidate proxy in front of `api.csearch.org`. Solves the
"frontend SSG sees stale data" half of the freshness problem (see
`FINDINGS.md` §3, `docs/tasks.md` Phase 4).

```
client → api-cache.csearch.org (Worker) → api.csearch.org (FastAPI)
                  │
                  └── KV: csearch-api-cache (5 min fresh, 24 h SWR)
```

## Behavior

| Path                | Cached? | Notes                                          |
|---------------------|---------|------------------------------------------------|
| Any `GET *`         | yes     | Keyed by `pathname?sortedQueryString`.         |
| Any `POST/PUT/...`  | no      | Pass-through. Includes `POST /search/semantic`.|
| `Cache-Control: no-store` from origin | no | Pass-through.              |

Response headers:

- `X-Cache: HIT` — served from KV, age < 5 min, no origin call.
- `X-Cache: STALE` — served from KV, age 5 min – 24 h, background revalidate kicked off.
- `X-Cache: MISS` — fetched synchronously from origin.
- `X-Cache-Age` — entry age in seconds.

## First-time setup

Prereqs: `npm install`, a `CLOUDFLARE_API_TOKEN` with `Workers Scripts: Edit` +
`Workers KV Storage: Edit` permissions, `CLOUDFLARE_ACCOUNT_ID` set or selected
in `wrangler login`.

```bash
cd workers/api-cache
npm install

# 1. Provision KV namespaces
npx wrangler kv namespace create CACHE
npx wrangler kv namespace create CACHE --preview
# → copy the printed `id` and `preview_id` into wrangler.toml

# 2. Deploy
npx wrangler deploy

# 3. Add the custom domain (one-time, via dashboard or CLI)
#    Workers & Pages → csearch-api-cache → Settings → Triggers → Custom Domains
#    Add: api-cache.csearch.org
#    (Cloudflare auto-issues the cert via the existing csearch.org zone.)

# 4. Smoke test
curl -i https://api-cache.csearch.org/latest/hr | head -20
# Expect 200 + X-Cache: MISS on first hit, HIT on the second within 5 min.
```

## Wire the frontend

After the Worker is healthy, point the Nuxt build at it:

1. Update `.env.prod` (and the matching GitHub repo variable
   `NUXT_API_SERVER`):
   ```
   NUXT_API_SERVER=https://api-cache.csearch.org
   ```
2. Trigger a Pages rebuild — the SSG `useAsyncData` calls during `nuxt generate`
   will go through the Worker, and client-side hydration will hit the same URL.

## Local dev

```bash
npx wrangler dev
# Worker on http://localhost:8787, KV runs against the preview namespace.
```

To exercise SWR locally, hit the same path twice within 5 minutes (`HIT`),
wait 5+ min (`STALE` + background revalidate), then hit again (`HIT` again).

## Tuning

Constants live in `src/index.ts`:

- `FRESH_SECONDS` — fresh window (default 300, matches `Cache-Control: max-age=3600`
  on the API but more conservative; tighten if you ship late-breaking data).
- `STALE_SECONDS` — outer SWR window (default 86 400 / 24 h).
- `KV_TTL_SECONDS` — KV row expiry, slightly longer than `STALE_SECONDS`.

## What this does and does not do

- ✅ Absorbs API origin slowness — clients see edge latency on cache hits.
- ✅ Survives short FastAPI / Postgres outages via stale-fallback.
- ✅ Reduces redundant SSG fetches during Pages builds.
- ❌ Does not invalidate on data change. The scraper does not POST to the
   Worker. Freshness is bounded by `FRESH_SECONDS` + background revalidate.
   If we need surgical invalidation, add a `POST /_purge` route guarded by a
   shared secret and call it from the scraper success path.
- ❌ Does not cache POST `/search/semantic`. Semantic queries already hit the
   API directly via the existing pre-warm path.
