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
| `0007_embedding_model_index` | embedding-model column + supporting index |
| `0008_bill_uid` | stable `bill_uid` identity |
| `0009_ops_data_versions` | `ops.data_versions` cache-invalidation counters |

## Running

```bash
# Apply everything pending (uses PG* env vars, or pass --dsn)
python db/migrate.py --dsn postgresql://postgres:postgres@localhost:5432/csearch

python db/migrate.py --status     # show applied vs pending
python db/migrate.py --dry-run    # list pending without applying
```

The runner records each applied file in `public.schema_migrations` and never
re-applies it. There are no down-migrations: roll forward only.

### On the clusters

`migrate.py` is also the **single schema mechanism in production**. The
`db-migrate` Job (`k8s/{netcup,freya}-db/db-migrate-job.yaml`) runs this exact
runner from the `csearch-db-migrate` image against the cluster Postgres. Because
it is idempotent, one code path covers both **bootstrap** (empty DB → applies
everything) and **ongoing migration** (applies only what's pending) — there is
no initdb bootstrap SQL and no per-environment schema ConfigMap anymore.

- **netcup:** Argo syncs the Job on every deploy; the `zip-districts-seed` Job
  loads the ZCTA→district data (`db/seed/zip_districts.sql`) when empty.
- **freya:** applied by hand — `kubectl --context freya apply -k k8s/freya-db`.
  freya carries no seed: its prod row data (incl. `zip_districts`) arrives via
  **logical replication** from netcup. See [`replication/`](replication/).

## Rules

1. **Never** edit a migration that has been applied in any environment. Add a
   new numbered file instead.
2. Application code must **validate** schema, not create it. `upserter.py`
   checks the `nlp` tables exist with the right shape and fails loudly if not —
   it no longer creates them opportunistically.
3. Every environment applies the **same** sequence. dev/prod parity comes from
   running the same files in the same order.

## No more bootstrap copies

The old per-environment bootstrap SQL (`k8s/{netcup,freya}-db/001-schema.sql`,
the `002`/`003` add-ons) and the `check-schema-drift.sh` guard that kept them in
sync are **gone**. The `db-migrate` Job applies `db/migrations/` directly on the
clusters, so `0001` is now the sole source of the public schema — there is
nothing left to drift from. (`backend/scraper/schema.sql` remains only as the
Rust scraper's own local fixture and no longer bootstraps any cluster.)

## CI

`.github/workflows/ci.yml` starts a clean `pgvector/pgvector` Postgres, applies
all migrations, loads `db/seed/fixtures.sql`, runs `db/smoke.sql` (which
includes a real pgvector nearest-neighbor query), and runs the API test suite.
A schema change that breaks the migration sequence fails the build before any
image is pushed.
