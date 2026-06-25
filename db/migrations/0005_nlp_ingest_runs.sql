-- 0005 — nlp ingest run audit tables.
--
-- Makes pipeline integrity a first-class, queryable fact: every upserter run
-- writes a manifest row here so a partial or stale load is distinguishable
-- from a healthy one. See backend/nlp/project-tarp/upserter.py (--run-id) and
-- the /freshness + /search/semantic/coverage endpoints.

BEGIN;

CREATE SCHEMA IF NOT EXISTS nlp;

CREATE TABLE IF NOT EXISTS nlp.ingest_runs (
    id                     BIGSERIAL PRIMARY KEY,
    run_id                 TEXT NOT NULL UNIQUE,
    git_sha                TEXT,
    congress               INTEGER,
    source_root            TEXT,
    status                 TEXT NOT NULL DEFAULT 'running'
                               CHECK (status IN ('running', 'success', 'failed')),
    input_bill_count       INTEGER,
    changed_bill_count     INTEGER,
    chunk_count            INTEGER,
    token_count            BIGINT,
    embedding_model        TEXT,
    embedding_dimensions   INTEGER,
    shard_count            INTEGER,
    shard_checksums        JSONB,
    upserted_chunk_count   INTEGER,
    started_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at            TIMESTAMPTZ,
    error                  TEXT
);

CREATE INDEX IF NOT EXISTS ingest_runs_started_at_idx ON nlp.ingest_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS ingest_runs_status_idx ON nlp.ingest_runs (status, started_at DESC);

CREATE TABLE IF NOT EXISTS nlp.ingest_run_items (
    id          BIGSERIAL PRIMARY KEY,
    run_id      TEXT NOT NULL REFERENCES nlp.ingest_runs(run_id) ON DELETE CASCADE,
    bill_id     TEXT NOT NULL,
    chunk_count INTEGER NOT NULL DEFAULT 0,
    action      TEXT NOT NULL DEFAULT 'upserted'
                    CHECK (action IN ('upserted', 'deleted', 'skipped'))
);

CREATE INDEX IF NOT EXISTS ingest_run_items_run_id_idx ON nlp.ingest_run_items (run_id);
CREATE INDEX IF NOT EXISTS ingest_run_items_bill_id_idx ON nlp.ingest_run_items (bill_id);

COMMIT;
