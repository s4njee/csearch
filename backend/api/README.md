# FastAPI API Rewrite

This directory is the first FastAPI pass for the CSearch read API.

Current scope:

- root and health checks
- latest bill lists
- bill search, including the `table=all` and `filter=relevance|date` contract used by the NLP workflow

The existing Fastify service remains in `backend/api/` while the rewrite grows.

## Layout

- `src/csearch_api/main.py` creates the FastAPI app
- `src/csearch_api/db.py` manages the async Postgres pool
- `src/csearch_api/cache.py` wraps Redis with fail-open semantics
- `src/csearch_api/queries.py` holds the bill list and search SQL
- `src/csearch_api/routes/` contains the first routers

## Run locally

```bash
cd backend/api
python -m pip install -e ".[dev]"
uvicorn csearch_api.main:app --host 0.0.0.0 --port 3000
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

