# CSearch API (FastAPI) — polish backlog

Polish items for `backend/api` (the read API the frontend consumes at
api.csearch.org). The other backend services (`scraper/` Rust+Python, `nlp/`
submodule, `log-collector/` Go) are out of scope here.

`P1` = high impact / low effort, `P2` = worthwhile, `P3` = nice-to-have / larger.

> Status: this batch is implemented and verified — `ruff`, `mypy`, and `pytest`
> (49 tests, ~77% coverage) all green. A pre-existing bug was also fixed: the
> `/explore/{id}` route read `result["sql"]`/`["bindings"]` which the lib now
> intentionally omits, 500-ing every non-search explore query.

---

## API contract & docs
- [x] **P1 Wire `response_model` onto routes** — every route now declares a model from `models.py`. Models use `extra="allow"` + all-optional/loose fields so they document the shape without dropping or coercing any field (verified: int `billid` preserved, undeclared columns pass through, nulls kept).
- [x] **P1 OpenAPI metadata** — `FastAPI(title/version/description)` + per-router `tags` + per-route docstrings.
- [x] **P2 README env vars** — full, grouped list with defaults in `README.md`.
- [x] **P2 Standardize the error schema** — `ErrorResponse` applied to all routers via `include_router(responses=ERROR_RESPONSES)`.
- [x] **P3 API versioning** — data routes are served (and documented) under `/v1`; the unversioned paths remain as hidden back-compat aliases so the current frontend keeps working. (Frontend can migrate to `/v1` later.)

## Performance & data path
- [x] **P1 Route reads through `read_fetch()`** — added `read_fetch/read_fetchrow/read_fetchval/read_raw` to `Database`; all user-facing GET handlers use them, so a configured `READ_POSTGRESURI` offloads reads. Health/freshness/metrics stay on the primary.
- [x] **P2 `/metrics` query cost** — the freshness/corpus gauges are refreshed at most once per `METRICS_GAUGE_TTL_SECONDS` (60s).
- [x] **P2 Caching consistency + invalidation** — `bills/bynumber` now cached; added `POST /admin/cache/reset` (token-guarded) as the invalidation hook. Search stays uncached (documented: high-cardinality keys).
- [x] **P3 Server-side pagination** — optional `limit`/`offset` on `latest_bills`, `search_bills`, `latest_votes` (defaults preserve the historical response; limit clamped).

## Robustness & ops
- [x] **P2 Dependency injection** — `deps.py` provides `get_db`/`get_cache`/`get_app_settings`; data + meta routes use `Depends`. (Semantic routes keep `app.state` access due to their module-level helper structure.)
- [x] **P2 Request correlation IDs** — `X-Request-ID` accepted/minted in middleware, echoed on responses, and logged.
- [x] **P2 Health/readiness split** — `/livez` (process) and `/readyz` (DB + Redis via `Cache.ping`); `/health` kept for back-compat.
- [x] **P3 General rate limiting** — opt-in `GLOBAL_RATE_LIMIT_PER_MINUTE` middleware (0 = off, default), probes exempt, fails open.
- [ ] **P3 `/metrics` exposure** — left world-readable by design (Prometheus scrapes can't carry a token); restrict at the ingress/network-policy layer (infra, not app code). Exempted from the global rate limit.

## Build & tooling
- [x] **P1 Add Ruff + mypy** — configured in `pyproject.toml` and wired into CI (`.github/workflows/ci.yml`); both pass clean.
- [x] **P2 Dockerfile hardening** — non-root user, `HEALTHCHECK` on `/livez`, non-editable install (explore.sql path made env-overridable via `CSEARCH_EXPLORE_SQL`).
- [x] **P2 Expand tests** — added `tests/test_ops.py` (livez/readyz, request-id, admin reset, pagination, bynumber caching, rate limit); 38 → 49 tests.
- [x] **P3 Coverage reporting** — `pytest-cov` added; CI runs `--cov` with term-missing.

## Code health
- [x] **P2 Typed handler returns** — the typed contract is provided by `response_model` (mypy-verified); explicit `-> Model` annotations are intentionally avoided since handlers return plain dicts/rows.
- [x] **P3 Consolidate inline SQL** — the five bill-detail queries moved to `queries.py` (`BILL_DETAIL_*`).
- [x] **P3 CORS in prod** — documented in `README.md` (set `CORS_ALLOW_ORIGINS` to the known origin in production).
