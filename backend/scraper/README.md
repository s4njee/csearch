# Backend Scraper

The scraper is the ingest side of CSearch. It fetches raw congressional data, normalizes it, and writes it into Postgres.

This project is intentionally hybrid:

- Python handles source acquisition through the vendored `unitedstates/congress` project
- Go handles CSearch-specific parsing, deduplication, hashing, cache invalidation, and database writes

If data is missing or wrong in Postgres, start here.

## What This Project Owns

The scraper owns:

- source acquisition for bills and votes
- normalized bill and vote parsing
- hash-based skip logic for unchanged files
- schema bootstrap SQL
- SQL source used by generated Go query code
- shared Redis cache invalidation after successful writes

The scraper does not own:

- HTTP response shapes
- frontend page behavior

## Run Lifecycle

A normal scraper run does the following:

1. load config and connect to Postgres
2. load the persisted bill and vote hash caches
3. run the vendored Python scraper for bills and or votes
4. walk the downloaded files for each supported congress
5. skip files whose SHA-256 hash has not changed
6. parse changed files into normalized bill or vote structures
7. upsert rows into Postgres
8. clear `csearch:*` Redis keys if any rows changed
9. persist the updated hash caches

## Data Coverage

| Data type | Range |
| --- | --- |
| Bills | 93rd Congress through current |
| Votes | 101st Congress through current |

The current congress is computed dynamically from the current year.

## Runtime Directory Layout

The scraper expects `CONGRESSDIR` to point at a runtime root with this shape:

```text
<CONGRESSDIR>/
  congress/
    run.py
    data/
      <congress>/
        bills/
        votes/
  data/
    fileHashes.gob
    voteHashes.gob
```

Important detail:

- raw downloaded source files live under `congress/data/...`
- hash caches live under `data/...`

## Key Files

| Path | Purpose |
| --- | --- |
| `main.go` | run orchestration, feature flags, final run summary |
| `runtime.go` | config loading, DB connection, Python task runner, Redis invalidation |
| `bills.go` | bill parsing and DB insert logic |
| `votes.go` | vote parsing and DB insert logic |
| `hashes.go` | SHA-256 hash cache storage |
| `schema.sql` | database bootstrap schema |
| `query.sql` | SQL source for generated Go query methods |
| `csearch/*.go` | `sqlc`-generated Go code, do not edit by hand |
| `explore.sql` | source of truth for API explore queries |
| `congress/` | vendored Python scraper code |

## Most Common Edit Points

| File | Edit this when |
| --- | --- |
| `main.go` | run sequencing, top-level flags, summary logging, or invalidation timing changes |
| `runtime.go` | environment handling, DB setup, Python subprocess invocation, or Redis config changes |
| `bills.go` | a bill field is missing or wrong, upstream bill XML changed, or bill child tables need different insert behavior |
| `votes.go` | vote fields are missing or incorrect, vote normalization needs to change, or vote source format changed |
| `hashes.go` | skip logic or hash-cache persistence needs to change |
| `schema.sql` | tables, indexes, or search-related DB objects need to change |
| `query.sql` | generated Go queries need new inputs, outputs, or SQL behavior |
| `congress/tasks/utils.py` | low-level fetch behavior or request pacing must change |

## Environment Variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `CONGRESSDIR` | Yes | runtime root for scraper code, raw data, and hash caches |
| `POSTGRESURI` | Yes | Postgres host |
| `REDIS_URL` | No | Redis connection string used for API cache invalidation, defaults to `redis://localhost:6379` |
| `DB_PORT` | No | Postgres port, defaults to `5432` |
| `DB_USER` | No | Postgres user, defaults to `postgres` |
| `DB_PASSWORD` | No | Postgres password, defaults to `postgres` |
| `DB_NAME` | No | database name, defaults to `csearch` |
| `RUN_BILLS` | No | enable bill sync and ingest, defaults to `true` |
| `RUN_VOTES` | No | enable vote sync and ingest, defaults to `true` |
| `LOG_LEVEL` | No | `debug`, `info`, `warn`, or `error` for Go logs |

## Direct Development

Run tests:

```bash
cd backend/scraper
go test ./...
```

Run the updater directly:

```bash
cd backend/scraper
CONGRESSDIR=/path/to/runtime-root \
POSTGRESURI=localhost \
DB_PORT=5433 \
REDIS_URL=redis://localhost:6379 \
DB_USER=postgres \
DB_PASSWORD=postgres \
DB_NAME=csearch \
RUN_BILLS=true \
RUN_VOTES=true \
go run .
```

Notes:

- `CONGRESSDIR` must contain both `congress/` and `data/`
- if `data/` does not exist yet, the updater creates it when saving hash caches
- the vendored Python scraper is expected at `backend/scraper/congress` for direct local runs

### Run only one side of the ingest

Examples:

```bash
RUN_BILLS=false RUN_VOTES=true go run .
RUN_BILLS=true RUN_VOTES=false go run .
```

There is also a legacy Python test suite inside `congress/test/`, but most CSearch-specific correctness lives in the Go parser and insert logic.

## Deployment

Argo CD is the default deployment path for the scraper.

Default deployment entry points:

- [`argo/applications/csearch-netcup-scraper.yaml`](../../argo/applications/csearch-netcup-scraper.yaml)
- [`k8s/netcup-scraper/cronjob.yaml`](../../k8s/netcup-scraper/cronjob.yaml)
- [`k8s/netcup-scraper/kustomization.yaml`](../../k8s/netcup-scraper/kustomization.yaml)

### Build the scraper image

Run from the repo root because the Dockerfile copies files using root-relative paths:

```bash
source .env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-updater:latest" \
  -f backend/scraper/Dockerfile .
```

### Trigger a manual run in the cluster

```bash
kubectl create job csearch-updater-manual-$(date +%s) --from=cronjob/csearch-updater
kubectl logs -f job/<job-name>
```

## Generated And Vendored Files

### `sqlc` generated code

Do not hand-edit:

- `csearch/db.go`
- `csearch/models.go`
- `csearch/query.sql.go`

If you change SQL in `query.sql`, regenerate the `sqlc` output instead of editing generated files directly.

### Vendored Python scraper

`congress/` is a vendored copy of the upstream Python scraper. Change it only when:

- fetch behavior needs to change
- upstream source format changed
- the Go updater needs a different raw input layout

Most application-level fixes belong in the Go code, not in the vendored Python code.

## Troubleshooting

### A scraper run completes but no records changed

Check:

- whether the source files actually changed
- whether the relevant hash cache already contains the new digest
- whether `RUN_BILLS` or `RUN_VOTES` disabled part of the run

### The updater cannot find the Python scraper

Check `CONGRESSDIR`. The updater looks for `CONGRESSDIR/congress/run.py` first and falls back to the bundled image path only in containerized runtime.

### Bills or votes are skipped unexpectedly

Look at:

- `hashes.go`
- the structured log lines about skipped or failed files
- the raw source files under `congress/data/...`

### Cache invalidation did not seem to happen

Check:

- whether the run actually changed any bill or vote rows
- whether `REDIS_URL` points at the expected Redis instance
- whether Redis was reachable during the run

### A schema-related insert starts failing after an update

Check:

- `schema.sql`
- `query.sql`
- the generated `csearch/*.go` code

Those three need to stay aligned.
