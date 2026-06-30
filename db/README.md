# Database Migrations

Versioned, forward-only SQL migrations are the **source of truth** for the
CSearch database schema. This replaces the previous mix of bootstrap SQL,
runtime `CREATE TABLE IF NOT EXISTS`, and hand-applied one-off jobs.

_Last verified against code: 2026-05-30._

## Layout

```
db/
  migrations/        NNNN_name.sql, applied in filename order
  seed/fixtures.sql  tiny deterministic corpus for local dev + CI smoke
  smoke.sql          schema + pgvector assertions (RAISEs on failure)
  migrate.py         the runner
```

| Migration | Owns |
| --- | --- |
| `0000_roles` | the `csearch` ownership role + public/database grants |
| `0001_initial_public_schema` | bills, votes, committees, FTS, `search_bills`/`search_votes` |
| `0002_nlp_bill_vectors` | `nlp` chunk/embedding tables + HNSW indexes |
| `0003_zip_districts` | ZIP→district lookup table (data seeded separately) |
| `0004_audit_history` | `audit.row_history`, first/last-seen tracking |
| `0005_nlp_ingest_runs` | `nlp.ingest_runs` / `ingest_run_items` pipeline audit |
| `0006_ops_job_runs` | `ops.scraper_runs` / `nlp_runs` / `frontend_deploys` |

## Running

```bash
# Apply everything pending (uses PG* env vars, or pass --dsn)
python db/migrate.py --dsn postgresql://postgres:postgres@localhost:5432/csearch

python db/migrate.py --status     # show applied vs pending
python db/migrate.py --dry-run    # list pending without applying
```

The runner records each applied file in `public.schema_migrations` and never
re-applies it. There are no down-migrations: roll forward only.

## Rules

1. **Never** edit a migration that has been applied in any environment. Add a
   new numbered file instead.
2. Application code must **validate** schema, not create it. `upserter.py`
   checks the `nlp` tables exist with the right shape and fails loudly if not —
   it no longer creates them opportunistically.
3. Every environment applies the **same** sequence. dev/prod parity comes from
   running the same files in the same order.

## Relationship to the legacy bootstrap files

`backend/scraper/schema.sql` and `k8s/{netcup,freya}-db/001-schema.sql` still
bootstrap the live clusters on first container start. `0001` is kept
**byte-identical** to them (below its header). `scripts/check-schema-drift.sh`
fails CI if they diverge, so there is one effective source of truth even while
the cluster bootstrap path is migrated over.

## CI

`.github/workflows/ci.yml` starts a clean `pgvector/pgvector` Postgres, applies
all migrations, loads `db/seed/fixtures.sql`, runs `db/smoke.sql` (which
includes a real pgvector nearest-neighbor query), and runs the API test suite.
A schema change that breaks the migration sequence fails the build before any
image is pushed.
