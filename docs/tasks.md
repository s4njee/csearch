# Tasks — Fix Bill Freshness (FINDINGS.md §3)

Goal: drop end-to-end staleness from 3–5 days to ≤12 hours.

Root cause (per `FINDINGS.md:104–113`): scraper + API are fresh within minutes, but the Nuxt site is `generate`-d and Cloudflare Pages only rebuilds on push to `main` and once daily at 12:00 UTC. A scrape doesn't reach users until the next build.

---

## Phase 1 — Event-driven Pages deploy (priority: highest, ~1 day)

Make the frontend rebuild when scraper data lands instead of on a wall-clock timer.

- [ ] Create a Cloudflare Pages deploy hook for the production project; store the URL as a sealed secret (`CLOUDFLARE_PAGES_DEPLOY_HOOK`).
- [ ] Add a post-success step to the scraper CronJob (`k8s/netcup-scraper/cronjob.yaml`) that `curl -X POST`s the deploy hook only when the scraper container exits 0 and reports non-empty changes.
  - Decide signal: parse scraper stdout for a "rows changed" marker, or have the scraper write a sentinel to Redis that a sidecar reads.
  - Skip the trigger when the run is a no-op so we don't churn builds.
- [ ] Mirror the trigger in `.github/workflows/build-images.yml` for the manual-rerun path so out-of-band scrapes also redeploy.
- [ ] Add a 30-min timeout + retry (max 2) around the webhook call; log to log-collector on failure.
- [ ] Verify in staging: run the scraper, confirm the Pages build kicks off within ~1 min, confirm the new bill is visible on the public site after build completes.

## Phase 2 — Dual-frequency scraper (priority: medium, ~1 day)

Catch GovInfo posts that land after the morning run.

- [ ] Add a second CronJob entry (or a second schedule) at `0 15 * * *` UTC (10:00 CT) in `k8s/netcup-scraper/orchestrator-cronjob.yaml`.
- [ ] Confirm the scraper is idempotent across overlapping runs — check `backend/scraper/src/db.rs` upsert paths and Redis lock keys.
- [ ] Add a guard so a still-running 05:00 job doesn't clash with the 10:00 job (k8s `concurrencyPolicy: Forbid`).
- [ ] Update `ARCHITECTURE.md:281` (build cadence note) and any runbook references to the new schedule.
- [ ] Watch one week of runs to confirm the second job actually finds new rows (justifies keeping it).

## Phase 3 — Cache + headers tightening (priority: medium, low effort)

Pair-fix from §2.5 of FINDINGS — keeps explore endpoints from serving day-old rows when only metadata changed.

- [ ] In `backend/api/routes/explore.py`, drop explore-endpoint TTL from 24 h to 12 h.
- [ ] Emit `Cache-Control: max-age=3600, stale-while-revalidate=86400` from explore + bill detail responses so Cloudflare's edge does SWR.
- [ ] Verify scraper-driven hard invalidation in `backend/scraper/src/redis_cache.rs` still clears the relevant keys on content changes (no regression).

## Phase 4 — ISR/SWR via Cloudflare Worker + KV (priority: durable fix, 1–2 days)

Architectural backstop — survives any future build-cadence regression.

- [ ] Provision a KV namespace (`csearch-isr`) in the Cloudflare account; record the binding.
- [ ] Add `wrangler.toml` for a new Worker that sits in front of `/bills/*` and `/votes/*` JSON paths.
- [ ] Worker logic: serve from KV if fresh; on stale, return cached + revalidate from API in the background; write fresh response back to KV with a short hard TTL (~5 min) and a longer SWR window (~24 h).
- [ ] Decide hydration model for detail pages: keep static HTML and have the page fetch via the Worker on mount, OR move detail pages to dynamic rendering through the Worker. Pick one and document in `frontend/nuxt.config.ts` notes.
- [ ] Smoke-test: post a bill update, confirm next request ≤2 s shows new data without a Pages rebuild.

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
