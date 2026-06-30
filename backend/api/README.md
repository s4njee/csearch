# CSearch FastAPI API

This directory contains the active CSearch read API.

Current scope:

- root, health, and freshness checks
- latest bill and vote lists
- bill and vote search
- bill, member, committee, and representative lookup routes
- explore queries
- pgvector-backed semantic search

## Layout

- `src/csearch_api/main.py` creates the FastAPI app
- `src/csearch_api/db.py` manages the async Postgres pool
- `src/csearch_api/cache.py` wraps Redis with fail-open semantics
- `src/csearch_api/queries.py` holds shared bill list and search SQL
- `src/csearch_api/explore.py` loads and executes prebuilt explore queries
- `src/csearch_api/routes/` contains the route handlers

## Run locally

```bash
cd backend/api
python -m pip install -e ".[dev]"
uvicorn csearch_api.main:app --host 0.0.0.0 --port 3000
```

Run the checks (lint, types, tests) with:

```bash
cd backend/api
ruff check .          # lint
mypy                  # type-check (src/)
pytest -q             # tests
```

## Environment variables

All settings are read from the environment (or a `.env` file); defaults in
parentheses. See `src/csearch_api/settings.py`.

Server:

- `HOST` (`0.0.0.0`), `PORT` (`3000`), `LOG_LEVEL` (`info`)

Database:

- `POSTGRESURI` (`localhost`), `DB_PORT` (`5432`), `DB_USER` (`postgres`),
  `DB_PASSWORD` (`postgres`), `DB_NAME` (`csearch`)
- `READ_POSTGRESURI` (empty) — optional read-replica DSN. When set, GET routes
  read from the replica pool; empty routes all reads to the primary.

Cache:

- `REDIS_URL` (`redis://localhost:6379`)
- `CACHE_TTL_SECONDS` (`86400`)
- `ADMIN_TOKEN` (empty) — enables `POST /admin/cache/reset` (sent via the
  `X-Admin-Token` header). Empty disables that endpoint.

Semantic search (OpenAI):

- `OPENAI_API_KEY` (empty) — required for `/search/semantic`; empty returns 503.
- `SEMANTIC_MAX_QUERY_CHARS` (`1000`), `SEMANTIC_RATE_LIMIT_PER_MINUTE` (`30`)
- `SEMANTIC_OPENAI_TIMEOUT_SECONDS` (`2.0`),
  `SEMANTIC_CIRCUIT_BREAKER_THRESHOLD` (`5`),
  `SEMANTIC_CIRCUIT_BREAKER_COOLDOWN_SECONDS` (`60`)

Rate limiting / CORS:

- `GLOBAL_RATE_LIMIT_PER_MINUTE` (`0` = disabled) — coarse per-IP limit on all
  routes except `/health`, `/livez`, `/readyz`, `/metrics`.
- `CORS_ALLOW_ORIGINS` (`*`) — comma-separated allowlist. `*` keeps the API open
  (credentials then disabled, per the CORS spec). **In production, set this to
  the known frontend origin(s)** (e.g. `https://csearch.org`) to narrow the
  blast radius.

## Health & readiness

- `GET /livez` — process is up (no dependencies probed).
- `GET /readyz` — DB + Redis reachable (503 otherwise).
- `GET /health` — DB connectivity (kept for back-compat).
