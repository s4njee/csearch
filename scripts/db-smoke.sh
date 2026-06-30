#!/usr/bin/env bash
# Spin up an ephemeral pgvector Postgres, apply all migrations, load fixtures,
# and run the schema + pgvector smoke assertions. Used by `make db-smoke` and CI.
#
# If PG_SMOKE_DSN is set, runs against that database instead of starting a
# container (used in CI where a service container already exists).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CONTAINER="csearch-db-smoke-$$"
started_container=0

cleanup() {
  if (( started_container )); then docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

if [[ -n "${PG_SMOKE_DSN:-}" ]]; then
  DSN="$PG_SMOKE_DSN"
else
  echo "Starting ephemeral pgvector container..."
  docker run -d --name "$CONTAINER" \
    -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=csearch \
    -p 55433:5432 pgvector/pgvector:pg16 >/dev/null
  started_container=1
  DSN="postgresql://postgres:postgres@localhost:55433/csearch"
  for i in $(seq 1 45); do
    if docker exec "$CONTAINER" pg_isready -U postgres -d csearch >/dev/null 2>&1; then break; fi
    sleep 1
  done
fi

echo "Applying migrations..."
python3 db/migrate.py --dsn "$DSN"

echo "Loading fixtures..."
psql "$DSN" -v ON_ERROR_STOP=1 -q -f db/seed/fixtures.sql

echo "Running smoke assertions..."
psql "$DSN" -v ON_ERROR_STOP=1 -f db/smoke.sql

echo "DB smoke passed."
