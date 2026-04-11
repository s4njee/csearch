#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SMOKE_DIR="$ROOT_DIR/backend/scraper/smoke"
COMPOSE_FILE="$SMOKE_DIR/docker-compose.benchmark.yml"
SCHEMA_FILE="$ROOT_DIR/backend/scraper/schema.sql"

SOURCE_CONGRESS_DIR="${SOURCE_CONGRESS_DIR:-}"
PROJECT_NAME="${PROJECT_NAME:-rscraper-seed-bench-$(date +%s)}"
KEEP_RUNTIME="${KEEP_RUNTIME:-0}"

if [[ -z "$SOURCE_CONGRESS_DIR" ]]; then
  echo "SOURCE_CONGRESS_DIR is required (example: /home/sanjee/congress)" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_CONGRESS_DIR" ]]; then
  echo "SOURCE_CONGRESS_DIR does not exist: $SOURCE_CONGRESS_DIR" >&2
  exit 1
fi

RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rscraper-seed-bench.XXXXXX")"
RESULTS_DIR="$RUNTIME_DIR/results"

export COMPOSE_PROJECT_NAME="$PROJECT_NAME"
export SMOKE_RUNTIME_DIR="$RUNTIME_DIR"

cleanup() {
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans >/dev/null 2>&1 || true
  if [[ "$KEEP_RUNTIME" != "1" ]]; then
    rm -rf "$RUNTIME_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$RESULTS_DIR" "$RUNTIME_DIR/data"

wait_for_postgres() {
  for _ in $(seq 1 60); do
    if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U postgres -d csearch >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

reset_db() {
  docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL' >/dev/null
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'csearch') THEN
        CREATE ROLE csearch LOGIN PASSWORD 'postgres';
    END IF;
END $$;
GRANT csearch TO postgres;
SQL

  docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres -d csearch -v ON_ERROR_STOP=1 <<'SQL' >/dev/null
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public AUTHORIZATION postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO csearch;
SQL

  docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres -d csearch -v ON_ERROR_STOP=1 < "$SCHEMA_FILE" >/dev/null
}

reset_hashes() {
  rm -f "$RUNTIME_DIR/data/fileHashes.rscraper.bin" "$RUNTIME_DIR/data/voteHashes.rscraper.bin"
}

run_seed_case() {
  local concurrency="$1"
  local log_file="$RESULTS_DIR/concurrency-${concurrency}.log"
  local started_at ended_at wall_s scraper_s bill_count

  echo
  echo "==> Running seed benchmark with DB_WRITE_CONCURRENCY=$concurrency"

  reset_db
  reset_hashes

  started_at="$(python3 - <<'PY'
import time
print(f"{time.time():.6f}")
PY
)"

  docker compose -f "$COMPOSE_FILE" run --rm \
    -e DB_WRITE_CONCURRENCY="$concurrency" \
    -e BILL_WRITE_MODE=seed \
    -e BILL_SEED_CHUNK_SIZE=50 \
    -e RUN_BILLS=true \
    -e RUN_VOTES=false \
    rscraper 2>&1 | tee "$log_file"

  ended_at="$(python3 - <<'PY'
import time
print(f"{time.time():.6f}")
PY
)"

  wall_s="$(python3 - <<PY
start = float("$started_at")
end = float("$ended_at")
print(f"{end - start:.3f}")
PY
)"

  scraper_s="$(python3 - "$log_file" <<'PY'
import json
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
duration = ""
for line in log_path.read_text(encoding="utf-8").splitlines():
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        continue
    if payload.get("fields", {}).get("message") == "scraper run complete":
        duration = str(payload["fields"].get("duration_s", ""))
print(duration)
PY
)"

  bill_count="$(
    docker compose -f "$COMPOSE_FILE" exec -T postgres \
      psql -U postgres -d csearch -At \
      -c "select count(*) from bills;"
  )"

  printf "%s\t%s\t%s\t%s\n" "$concurrency" "$wall_s" "${scraper_s:-n/a}" "$bill_count"
}

echo "Building benchmark images..."
docker compose -f "$COMPOSE_FILE" build rscraper >/dev/null

echo "Starting benchmark Postgres..."
docker compose -f "$COMPOSE_FILE" up -d postgres >/dev/null

if ! wait_for_postgres; then
  echo "postgres did not become ready" >&2
  exit 1
fi

echo
echo "Concurrency	WallSeconds	ScraperDurationSeconds	BillRows"
run_seed_case 1
run_seed_case 2

echo
echo "Logs written under: $RESULTS_DIR"
