# Tasks — Fix Bill Freshness (FINDINGS.md §3)

Goal: drop end-to-end staleness from 3–5 days to ≤12 hours.

Root cause (per `FINDINGS.md:104–113`): scraper + API are fresh within minutes, but the Nuxt site is `generate`-d and Cloudflare Pages only rebuilds on push to `main` and once daily at 12:00 UTC. A scrape doesn't reach users until the next build.

---

## Phase 1 — Event-driven Pages deploy (priority: highest, ~1 day)

Make the frontend rebuild when scraper data lands instead of on a wall-clock timer.

- [ ] **(user)** Create a Cloudflare Pages deploy hook for the production project, then `kubeseal` the URL into `csearch-cloudflare-deploy-hook` (key `DEPLOY_HOOK_URL`) — placeholder manifests + commands at `k8s/{freya,netcup}-core/csearch-cloudflare-deploy-hook-sealedsecret.yaml`. Add the file to the matching `kustomization.yaml` after sealing.
- [x] Wire the trigger from the orchestrator CronJob: `nightly_update.sh` writes `$DATA_DIR/.deploy-pending` only after a successful upsert, and the cronjob args POST to `DEPLOY_HOOK_URL` (3 attempts, 30 s timeout, exponential backoff, never fails the job). Edits in:
  - `backend/nlp/project-tarp/nightly_update.sh`
  - `k8s/freya-scraper/orchestrator-cronjob.yaml`
  - `k8s/netcup-scraper/orchestrator-cronjob.yaml`
- [x] No-op skip is built in: `content_hasher.py` exits early when nothing changed, so the sentinel never gets touched and no deploy fires.
- [~] ~~Mirror the trigger in `.github/workflows/build-images.yml`~~ — skipped: that workflow only builds container images. Manual scrape reruns use `kubectl create job --from=cronjob/...`, which already exercises the same deploy-trigger path. The existing `frontend-cloudflare-deploy.yml` workflow_dispatch covers manual UI-only deploys.
- [x] 30 s timeout + 3 retries with exponential backoff; failures log to stderr and do not fail the Job (caught by log-collector via stderr capture).
- [ ] **(user)** Verify in staging: trigger an orchestrator run, confirm the Pages build kicks off, confirm the new bill is visible after build completes.

## Phase 2 — Dual-frequency scraper (priority: medium, ~1 day)

Catch GovInfo posts that land after the morning run.

- [x] Repurposed the previously-suspended scraper-only CronJob (`k8s/{freya,netcup}-scraper/cronjob.yaml`): `suspend: false`, schedule `0 10 * * *` America/Chicago. Pairs with the 05:00 orchestrator. Wraps the entrypoint to fire the same deploy hook on success.
- [x] Idempotency: the Rust scraper upserts and uses Redis-backed cache invalidation (`backend/scraper/src/redis_cache.rs`) — overlapping runs are safe.
- [x] `concurrencyPolicy: Forbid` already set on both CronJobs (10:00 won't race itself; orchestrator has its own Forbid). 05:00 → 10:00 gap is 5 h, well inside typical runtime.
- [ ] **(user)** Update `ARCHITECTURE.md:281` to document the new 10:00 CT schedule.
- [ ] **(user)** Watch one week of 10:00 runs to confirm the second job actually finds new rows.

## Phase 3 — Cache + headers tightening (priority: medium, low effort)

Pair-fix from §2.5 of FINDINGS — keeps explore endpoints from serving day-old rows when only metadata changed.

- [x] Added `EXPLORE_TTL_SECONDS = 12 h` constant in `backend/api/src/csearch_api/cache.py`; `Cache.set()` now accepts an optional `ttl` override. Explore route passes it.
- [x] Emit `Cache-Control: public, max-age=3600, stale-while-revalidate=86400` from `/explore/{query_id}` and `/bills/{billtype}/{congress}/{billnumber}`.
- [x] No regression in scraper-driven invalidation: `backend/scraper/src/redis_cache.rs` still clears keys on content changes (no code change there).
- [x] All 16 API tests pass after the changes (`pytest tests/`).

## Phase 4 — ISR/SWR via Cloudflare Worker + KV (priority: durable fix, 1–2 days)

Architectural backstop — survives any future build-cadence regression.

- [x] Worker scaffolded at `workers/api-cache/` (TypeScript, wrangler 3). Sits at `https://api-cache.csearch.org` and proxies to `https://api.csearch.org`. Caches all GETs (skips POST/PUT/...; `POST /search/semantic` therefore passes through). 5-min fresh window, 24-h SWR window, KV-backed. Response headers expose `X-Cache: HIT|STALE|MISS` + `X-Cache-Age`.
- [x] `wrangler.toml` declares KV binding `CACHE` and custom-domain route `api-cache.csearch.org`. `npx tsc --noEmit` and `wrangler deploy --dry-run` both clean.
- [x] Hydration model decision: **keep static HTML; client-side `useAsyncData` calls go through the Worker.** Cleanest because Nuxt SSG also runs `useAsyncData` at build time — pointing `NUXT_API_SERVER` at the Worker means SSG, hydration, and runtime fetches all share the same SWR cache. No Nuxt config rewrite needed.
- [x] Provision KV: `csearch-api-cache-CACHE` namespace created (prod + preview); real `id` / `preview_id` are in `wrangler.toml`.
- [x] Deploy: `npx wrangler deploy` done; `api-cache.csearch.org` live as a Custom Domain (auto-provisioned via the `custom_domain` route in `wrangler.toml`).
- [x] `NUXT_API_SERVER` set to `https://api-cache.csearch.org` (GH Actions repo variable + `.env.prod`); Pages rebuilt. Production traffic now flows browser → `api-cache.csearch.org` → `api.csearch.org`.
- [x] Smoke-tested in prod: `X-Cache: MISS → HIT`, POST `/search/semantic` passthrough, and CORS verified. One fix shipped — the Worker re-asserts `Access-Control-Allow-Origin: *` on Origin-bearing GET responses (origin only emits CORS when an `Origin` header is present, but the Worker caches by path+query and can fill from header-less SSG requests).
- [ ] Optional: surgical invalidation via a guarded `POST /_purge` called from the scraper success path, if the 5-min `FRESH_SECONDS` window proves too coarse.

## Phase 5 — Live push (optional, only if real-time UX is wanted)

Defer unless Phases 1–4 don't satisfy the use case. Big lift, small marginal payoff.

- [ ] Decide SSE vs WebSocket. SSE is simpler given one-way "data updated" events.
- [ ] Add an event channel in the API; publish on scraper-success webhook.
- [ ] Frontend subscribes on mount and soft-refetches affected queries.

---

## Validation / done criteria

- [ ] Measure baseline staleness on `main` for 3 consecutive days (scrape → user-visible time).
- [ ] After Phase 1 + 2, repeat measurement; expect p95 ≤ 12 h, p50 ≤ 1 h.
- [ ] Add a Grafana panel (or simple log query) tracking scrape-completed → pages-deployed delta so future regressions are visible.

## Out of scope

- Rewriting the scraper language (FINDINGS §1 — Rust is fine).
- Reworking Redis invalidation (already sound per FINDINGS Anti-Patterns §1).
