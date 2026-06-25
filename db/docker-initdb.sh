#!/usr/bin/env bash
# Postgres docker-entrypoint init hook: apply migrations then seed fixtures.
# Mounted into /docker-entrypoint-initdb.d so `docker compose up postgres`
# produces a fully migrated + seeded local database with no extra steps.
set -euo pipefail

DB="${POSTGRES_DB:-csearch}"
USER="${POSTGRES_USER:-postgres}"
PSQL=(psql -v ON_ERROR_STOP=1 --username "$USER" --dbname "$DB" --no-psqlrc --quiet)

"${PSQL[@]}" -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());"

for f in /opt/db/migrations/*.sql; do
  v="$(basename "$f" .sql)"
  echo "initdb: applying migration $v"
  "${PSQL[@]}" -f "$f"
  "${PSQL[@]}" -c "INSERT INTO public.schema_migrations(version) VALUES ('$v') ON CONFLICT DO NOTHING;"
done

if [ -f /opt/db/seed/fixtures.sql ]; then
  echo "initdb: loading seed fixtures"
  "${PSQL[@]}" -f /opt/db/seed/fixtures.sql
fi

echo "initdb: database ready (migrated + seeded)"
