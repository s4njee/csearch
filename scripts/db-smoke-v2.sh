#!/usr/bin/env bash
# V2 corpus drill: transform the v1 fixture corpus into nlp_stage.chunks,
# perform the atomic schema swap, assert the ENTIRE v1 read contract through
# the compat views, then roll back and assert v1 is intact.
#
# This is Phase 5's cutover drill run as a permanent CI check (see
# docs/V2-REFACTOR-PLAN.md): if a schema or API change ever breaks the swap
# path, CI goes red — not the production cutover.
#
# If PG_SMOKE_DSN is set, assumes scripts/db-smoke.sh already ran against it
# (migrated + fixtures loaded). Otherwise spins up an ephemeral pgvector
# container and prepares it here.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CONTAINER="csearch-db-smoke-v2-$$"
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
    -p 55434:5432 pgvector/pgvector:pg18 >/dev/null
  started_container=1
  DSN="postgresql://postgres:postgres@localhost:55434/csearch"
  for i in $(seq 1 60); do
    if psql "$DSN" -tAc "SELECT 1" >/dev/null 2>&1; then break; fi
    sleep 1
  done
  echo "Applying migrations..."
  python3 db/migrate.py --dsn "$DSN"
  echo "Loading fixtures..."
  psql "$DSN" -v ON_ERROR_STOP=1 -q -f db/seed/fixtures.sql
fi

PSQL=(psql "$DSN" -v ON_ERROR_STOP=1 -q)

echo "Transforming v1 fixture corpus into nlp_stage.chunks..."
"${PSQL[@]}" <<'SQL'
INSERT INTO nlp_stage.chunks (
    source_hash, bill_uid, congress, bill_type, bill_number, chunk_type,
    chunk_index, title, status, section_enum, section_header, body,
    token_count, embedding, embedding_model, created_at, updated_at)
SELECT
    c.source_hash, c.canonical_bill_id, c.congress, c.bill_type, c.bill_number,
    c.chunk_type, c.chunk_index, c.title, c.status, c.section_enum,
    c.section_header, c.body, c.token_count, e.embedding, e.model,
    c.created_at, c.updated_at
FROM nlp.bill_chunks c
JOIN nlp.bill_embeddings e ON e.chunk_id = c.id;

-- The transform is itself an audited reconcile.
INSERT INTO ops.reconcile_runs
    (run_id, status, finished_at, planned_add, executed_add,
     corpus_chunk_count, embedding_model)
SELECT 'ci-smoke-v2-' || to_char(now(), 'YYYYMMDDHH24MISSMS'), 'success', now(),
       count(*), count(*), count(*), min(embedding_model)
FROM nlp_stage.chunks;
SQL

echo "Swapping: nlp -> nlp_prev, nlp_stage -> nlp..."
"${PSQL[@]}" -f scripts/swap-nlp-stage.sql

echo "Asserting the v1 read contract through the v2 compat views..."
"${PSQL[@]}" <<'SQL'
DO $$
DECLARE
    n integer;
    query_vec vector;
    nearest text;
    last_run text;
    red integer;
BEGIN
    -- Counts survived the transform + swap.
    SELECT count(*) INTO n FROM nlp.bill_chunks;
    IF n <> 2 THEN RAISE EXCEPTION 'v2 view bill_chunks: expected 2, got %', n; END IF;
    SELECT count(*) INTO n FROM nlp.bill_embeddings;
    IF n <> 2 THEN RAISE EXCEPTION 'v2 view bill_embeddings: expected 2, got %', n; END IF;

    -- The retrieval join (chunk_id = id) works through the views.
    query_vec := (
        SELECT ('[' || string_agg(CASE WHEN g = 1 THEN '1' ELSE '0' END, ',') || ']')::vector
        FROM generate_series(1, 1536) g
    );
    SELECT c.bill_id INTO nearest
    FROM nlp.bill_chunks c
    JOIN nlp.bill_embeddings e ON e.chunk_id = c.id
    ORDER BY e.embedding <=> query_vec
    LIMIT 1;
    IF nearest <> 'hr42-119' THEN
        RAISE EXCEPTION 'v2 vector search returned %, expected hr42-119', nearest;
    END IF;

    -- Coverage anti-join (semantic.py) still sees every bill chunked.
    SELECT count(*) INTO n
    FROM public.bills b
    WHERE NOT EXISTS (
        SELECT 1 FROM nlp.bill_chunks c
        WHERE c.bill_type = b.billtype
          AND c.bill_number = b.billnumber::text
          AND c.congress = b.congress
    );
    IF n <> 0 THEN RAISE EXCEPTION 'v2 coverage: % bills missing chunks', n; END IF;

    -- /freshness + smoke read nlp.ingest_runs: now a view over reconcile_runs.
    SELECT status INTO last_run FROM nlp.ingest_runs ORDER BY started_at DESC LIMIT 1;
    IF last_run IS DISTINCT FROM 'success' THEN
        RAISE EXCEPTION 'v2 ingest_runs view: expected success, got %', last_run;
    END IF;

    -- All invariants green post-swap (five checks as of migration 0012).
    SELECT count(*) INTO red FROM ops.check_invariants() WHERE NOT ok;
    IF red <> 0 THEN RAISE EXCEPTION '% invariant(s) red after swap', red; END IF;

    RAISE NOTICE 'v2 swap assertions passed.';
END $$;
SQL

echo "Rolling back: nlp -> nlp_stage, nlp_prev -> nlp..."
"${PSQL[@]}" -f scripts/rollback-nlp-swap.sql

echo "Asserting v1 corpus intact after rollback..."
"${PSQL[@]}" <<'SQL'
DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n FROM nlp.bill_chunks;
    IF n <> 2 THEN RAISE EXCEPTION 'post-rollback v1 chunks: expected 2, got %', n; END IF;
    SELECT count(*) INTO n FROM nlp.bill_embeddings;
    IF n <> 2 THEN RAISE EXCEPTION 'post-rollback v1 embeddings: expected 2, got %', n; END IF;
    -- The v2 corpus is preserved as the stage for a potential re-swap.
    SELECT count(*) INTO n FROM nlp_stage.chunks;
    IF n <> 2 THEN RAISE EXCEPTION 'post-rollback stage chunks: expected 2, got %', n; END IF;
    RAISE NOTICE 'rollback assertions passed.';
END $$;
SQL

echo "DB smoke v2 (stage -> swap -> verify -> rollback) passed."
