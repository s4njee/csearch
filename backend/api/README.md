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

Run tests with:

```bash
cd backend/api
pytest
```

## Environment variables

- `HOST`
- `PORT`
- `LOG_LEVEL`
- `POSTGRESURI`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`
- `REDIS_URL`
