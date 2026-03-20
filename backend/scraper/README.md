# Backend Scraper

The scraper is the ingest side of CSearch. It fetches congressional source data, normalizes it, and writes it into Postgres.

This project is a hybrid:

- Python handles raw source acquisition through a vendored copy of `unitedstates/congress`
- Go handles CSearch-specific parsing, deduplication, and database writes

If you need to understand why data is or is not present in Postgres, this is the place to start.

## What This Project Owns

The scraper owns:

- source acquisition for bills and votes
- normalized bill and vote parsing
- hash-based skip logic for unchanged files
- schema bootstrap SQL
- SQL source files used by generated Go query code

The scraper does not own:

- HTTP response shapes
- frontend page behavior

## Run Lifecycle

A normal scraper run does the following:

1. Load environment and connect to Postgres
2. Load the persisted bill and vote hash caches
3. Run the vendored Python scraper for votes and or bills
4. Walk the downloaded files for each supported congress
5. Skip files whose SHA-256 hash has not changed
6. Parse changed files into normalized bill or vote structures
7. Upsert rows into Postgres
8. Persist the updated hash caches

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

That separation is easy to miss when debugging local runs.

## Key Files

| Path | Purpose |
| --- | --- |
| `main.go` | Overall run orchestration and feature flags |
| `runtime.go` | Config loading, DB connection, Python task runner |
| `bills.go` | Bill parsing and database insert logic |
| `votes.go` | Vote parsing and database insert logic |
| `hashes.go` | SHA-256 hash cache storage |
| `schema.sql` | Database bootstrap schema |
| `query.sql` | SQL source for generated Go query methods |
| `csearch/*.go` | `sqlc`-generated Go code, do not edit by hand |
| `explore.sql` | Source of truth for explore queries consumed by the API |
| `congress/` | Vendored Python scraper code |

## Most Used Files

These are the files most engineers touch when making normal ingest or schema changes.

### `main.go`

What it does:

- starts the scraper run
- reads the `RUN_BILLS` and `RUN_VOTES` feature flags
- opens Postgres
- loads hash caches
- orchestrates the bill and vote update flow
- emits the final run summary

Edit this when:

- run sequencing needs to change
- startup behavior changes
- new top-level run flags or summary logging are needed

### `runtime.go`

What it does:

- loads config from environment or `.env`
- opens the Postgres connection
- runs the vendored Python scraper as a subprocess
- streams Python output into structured logs

Edit this when:

- environment handling changes
- Postgres connection setup changes
- Python task invocation changes
- local and container runtime path behavior changes

### `bills.go`

What it does:

- scans bill files across supported congresses
- parses bill XML and legacy JSON shapes
- normalizes actions, cosponsors, committees, subjects, and summary fields
- writes bill data transactionally into Postgres

Edit this when:

- a bill field is missing or wrong in the database
- upstream bill XML changed
- a new normalized bill field needs to be captured
- bill-related child tables need different insert behavior

### `votes.go`

What it does:

- scans vote JSON files across supported congresses
- normalizes vote metadata and per-member positions
- maps vote keys like `Yea` or `Aye` to canonical forms
- writes vote and vote-member rows into Postgres

Edit this when:

- vote fields are missing or incorrect
- vote member position normalization needs to change
- vote source file shape changes

### `hashes.go`

What it does:

- computes SHA-256 digests for source files
- decides whether a file needs reprocessing
- persists the hash cache to disk

Edit this when:

- skip logic changes
- the hash-cache format changes
- you need to debug why changed files are being skipped or reprocessed

### `schema.sql`

What it does:

- bootstraps the Postgres schema used by the scraper and API
- defines the normalized tables, indexes, search helpers, and supporting database objects

Edit this when:

- new tables or columns are needed
- indexes or search-related database functions need to change
- the data model changes

### `query.sql`

What it does:

- defines the SQL statements that `sqlc` turns into generated Go query code

Edit this when:

- insert, upsert, or delete queries need to change
- the generated Go query methods need new inputs or outputs

Important:

- update `query.sql`, then regenerate `csearch/*.go`
- do not hand-edit the generated files

### `explore.sql`

What it does:

- stores the SQL query pack that powers the API explore feature

Edit this when:

- adding or changing analytical explore queries

Important:

- this file is the source of truth
- the API copy is overwritten during the full deploy flow

### `congress/tasks/utils.py`

What it does:

- contains the vendored Python scraper HTTP client behavior
- controls important source-fetch concerns such as request pacing

Edit this when:

- the low-level fetch behavior needs to change
- you are debugging an upstream download issue
- the source site requires scraper-level request handling changes

## Environment Variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `CONGRESSDIR` | Yes | Runtime root for scraper code, raw data, and hash caches |
| `POSTGRESURI` | Yes | Postgres host |
| `DB_PORT` | No | Postgres port, defaults to `5432` |
| `DB_USER` | No | Postgres user, defaults to `postgres` |
| `DB_PASSWORD` | No | Postgres password, defaults to `postgres` |
| `DB_NAME` | No | Database name, defaults to `csearch` |
| `RUN_BILLS` | No | Enable bill sync and ingest, defaults to `true` |
| `RUN_VOTES` | No | Enable vote sync and ingest, defaults to `true` |
| `LOG_LEVEL` | No | `debug`, `info`, `warn`, or `error` for Go logs |

## Local Development

### Easiest path

Run the scraper inside the compose stack:

```bash
docker-compose up postgres scraper
```

This is the best option when you just want a working local run with the right container layout.

### Run the Go updater directly

You can also run the Go updater without Docker. One workable local setup is:

```bash
cd backend/scraper
cat > .env <<'EOF'
CONGRESSDIR=/Users/your-user/Documents/projects/csearch-updater-root/backend/scraper
POSTGRESURI=localhost
DB_PORT=5433
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=csearch
RUN_BILLS=true
RUN_VOTES=true
EOF

go run .
```

Notes:

- `CONGRESSDIR` should be the directory that contains both `congress/` and `data/`
- if `data/` does not exist yet, the updater will create it when it saves hash caches
- for local development, the vendored Python scraper is expected at `backend/scraper/congress`

### Run only one side of the ingest

Examples:

```bash
RUN_BILLS=false RUN_VOTES=true go run .
RUN_BILLS=true RUN_VOTES=false go run .
```

This is useful when you are debugging only bills or only votes.

## Tests

Run Go tests from `backend/scraper/`:

```bash
go test ./...
```

There is also a legacy Python test suite inside `congress/test/`, but most CSearch-specific correctness lives in the Go parser and insert logic.

## Build And Deploy

### Build the scraper image

Run from the repo root because the Dockerfile copies files using root-relative paths:

```bash
source .env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-updater:latest" \
  -f backend/scraper/Dockerfile .
```

### Apply the scraper CronJob

```bash
kubectl apply -f k8s/scraper/cronjob.yaml
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

If you change SQL in `query.sql`, regenerate the `sqlc` output instead of editing the generated files directly.

### Vendored Python scraper

`congress/` is a vendored copy of the upstream Python scraper. Change it only when:

- the fetch behavior needs to change
- the upstream source format changed
- the Go updater needs a different raw input layout

Most application-level fixes belong in the Go code, not the vendored Python code.

## How The Python And Go Pieces Fit Together

`runtime.go` shells out to the Python scraper with commands like:

- `votes --congress=<current>`
- `govinfo --bulkdata=BILLSTATUS --congress=<current>`

After the raw files are present on disk, `bills.go` and `votes.go` scan all supported congress directories and process changed files.

That means the Python side is focused on fetching, while the Go side is focused on normalization and idempotent ingest.

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

### A schema-related insert starts failing after an update

Check:

- `schema.sql`
- `query.sql`
- the generated `csearch/*.go` code

Those three need to stay aligned.
