-- 0012 — V2 corpus schema, staged (V2 refactor Phase 1).
--
-- Creates the v2 data model in a schema named nlp_stage, alongside the live
-- v1 nlp schema. Nothing reads it until the atomic cutover
-- (scripts/swap-nlp-stage.sql) renames nlp -> nlp_prev, nlp_stage -> nlp.
-- Postgres references are OID-based, so the views inside nlp_stage keep
-- pointing at the right table across the rename. The same stage-then-swap
-- mechanism serves the v1->v2 migration, the green-env bootstrap on freya,
-- and every future risky rebuild (embedding-model swaps, HNSW rebuilds).
--
-- Design (docs/V2-REFACTOR-PLAN.md):
--   * ONE table: a chunk cannot exist without its embedding (NOT NULL) —
--     the orphan class that produced 129K dead embeddings on netcup is
--     unrepresentable, not merely checked.
--   * Run history lives in ops.reconcile_runs, NOT in the swapped schema,
--     so audit history survives cutovers.
--   * Compat views reproduce the v1 read contract (retrieval join, coverage
--     queries, /freshness, db/smoke.sql) so the API SQL ships unchanged.

BEGIN;

-- ---------------------------------------------------------------------------
-- Persistent reconcile audit (ops schema never swaps).
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS ops;

CREATE TABLE IF NOT EXISTS ops.reconcile_runs (
    id                 BIGSERIAL PRIMARY KEY,
    run_id             TEXT NOT NULL UNIQUE,
    congress           INTEGER,
    git_sha            TEXT,
    embedding_model    TEXT,
    started_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at        TIMESTAMPTZ,
    status             TEXT NOT NULL DEFAULT 'running'
                           CHECK (status IN ('running', 'success', 'failed', 'aborted')),
    -- the plan the reconciler computed ...
    planned_add        INTEGER,
    planned_update     INTEGER,
    planned_delete     INTEGER,
    -- ... and what it actually executed (must match the plan on success).
    executed_add       INTEGER,
    executed_update    INTEGER,
    executed_delete    INTEGER,
    corpus_bill_count  INTEGER,
    corpus_chunk_count INTEGER,
    error              TEXT
);

CREATE INDEX IF NOT EXISTS reconcile_runs_started_at_idx
    ON ops.reconcile_runs (started_at DESC);

-- ---------------------------------------------------------------------------
-- The v2 corpus table, staged.
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS nlp_stage;

CREATE TABLE IF NOT EXISTS nlp_stage.chunks (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_hash     TEXT NOT NULL UNIQUE,          -- content-addressed identity; reconciler diff key
    bill_uid        TEXT NOT NULL,                 -- 'hr1234-119'; joins public.bills.bill_uid
    congress        INTEGER NOT NULL,
    bill_type       TEXT NOT NULL,
    bill_number     TEXT NOT NULL,
    chunk_type      TEXT NOT NULL DEFAULT 'section',
    chunk_index     INTEGER NOT NULL,
    title           TEXT,
    status          TEXT,
    section_enum    TEXT,
    section_header  TEXT,
    body            TEXT NOT NULL,
    token_count     INTEGER NOT NULL,
    embedding       vector(1536) NOT NULL,         -- the invariant, structurally
    embedding_model TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chunks_bill_chunk_unique UNIQUE (bill_uid, chunk_index)
);

CREATE INDEX IF NOT EXISTS chunks_embedding_hnsw_idx
    ON nlp_stage.chunks USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 128);
CREATE INDEX IF NOT EXISTS chunks_bill_uid_idx        ON nlp_stage.chunks (bill_uid);
CREATE INDEX IF NOT EXISTS chunks_congress_idx        ON nlp_stage.chunks (congress);
CREATE INDEX IF NOT EXISTS chunks_embedding_model_idx ON nlp_stage.chunks (embedding_model);
CREATE INDEX IF NOT EXISTS chunks_created_at_idx      ON nlp_stage.chunks (created_at DESC);

-- ---------------------------------------------------------------------------
-- Compat views: the v1 read contract over the v2 table. After the swap these
-- become nlp.bill_chunks / nlp.bill_embeddings / nlp.ingest_runs, and every
-- existing API query (retrieval join on c.id = tk.chunk_id, coverage
-- anti-joins, /freshness, db/smoke.sql) runs unchanged.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW nlp_stage.bill_chunks AS
SELECT
    id,
    source_hash,
    bill_uid              AS bill_id,
    bill_uid              AS canonical_bill_id,
    congress,
    bill_type,
    bill_number,
    chunk_type,
    title,
    status,
    section_enum,
    section_header,
    chunk_index,
    chunk_index           AS original_chunk_index,
    body,
    token_count,
    created_at,
    updated_at
FROM nlp_stage.chunks;

CREATE OR REPLACE VIEW nlp_stage.bill_embeddings AS
SELECT
    id                    AS chunk_id,
    embedding,
    embedding_model       AS model,
    created_at
FROM nlp_stage.chunks;

-- /freshness?detail=true and db/smoke.sql read nlp.ingest_runs; post-swap the
-- reconcile audit answers in the same shape.
CREATE OR REPLACE VIEW nlp_stage.ingest_runs AS
SELECT
    id,
    run_id,
    congress,
    git_sha,
    status,
    started_at,
    finished_at,
    coalesce(executed_add, 0) + coalesce(executed_update, 0)
                          AS upserted_chunk_count,
    embedding_model,
    error
FROM ops.reconcile_runs;

-- ---------------------------------------------------------------------------
-- Extend the invariants (0010) with the reconcile audit. Function body is
-- restated in full — CREATE OR REPLACE, latest migration wins.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ops.check_invariants()
RETURNS TABLE (name text, ok boolean, detail text)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    n_orphan_embeddings bigint;
    n_chunks_no_embedding bigint;
    n_stuck bigint;
    n_models bigint;
    model_list text;
    last_scrape_success timestamptz;
    last_version_refresh timestamptz;
BEGIN
    -- 1. chunks_embeddings_1to1 (v1 tables; post-swap these are views over one
    --    table and the check is trivially green — by design).
    IF to_regclass('nlp.bill_embeddings') IS NOT NULL
       AND to_regclass('nlp.bill_chunks') IS NOT NULL THEN
        SELECT count(*) INTO n_orphan_embeddings
          FROM nlp.bill_embeddings e
         WHERE NOT EXISTS (SELECT 1 FROM nlp.bill_chunks c WHERE c.id = e.chunk_id);
        SELECT count(*) INTO n_chunks_no_embedding
          FROM nlp.bill_chunks c
         WHERE NOT EXISTS (SELECT 1 FROM nlp.bill_embeddings e WHERE e.chunk_id = c.id);
        RETURN QUERY SELECT
            'chunks_embeddings_1to1'::text,
            n_orphan_embeddings = 0 AND n_chunks_no_embedding = 0,
            format('%s orphaned embeddings, %s chunks without embeddings',
                   n_orphan_embeddings, n_chunks_no_embedding);
    ELSE
        RETURN QUERY SELECT 'chunks_embeddings_1to1'::text, true,
                            'nlp tables absent — skipped'::text;
    END IF;

    -- 2. no_stuck_runs (v1 ingest audit; post-swap the view maps reconcile_runs).
    IF to_regclass('nlp.ingest_runs') IS NOT NULL THEN
        SELECT count(*) INTO n_stuck
          FROM nlp.ingest_runs
         WHERE status = 'running'
           AND started_at < now() - interval '6 hours';
        RETURN QUERY SELECT
            'no_stuck_runs'::text,
            n_stuck = 0,
            format('%s ingest_runs stuck in running > 6h', n_stuck);
    ELSE
        RETURN QUERY SELECT 'no_stuck_runs'::text, true,
                            'nlp.ingest_runs absent — skipped'::text;
    END IF;

    -- 3. freshness_current.
    SELECT max(finished_at) INTO last_scrape_success
      FROM ops.scraper_runs WHERE status = 'success';
    SELECT max(refreshed_at) INTO last_version_refresh
      FROM ops.data_versions;
    RETURN QUERY SELECT
        'freshness_current'::text,
        last_scrape_success IS NULL
            OR (last_version_refresh IS NOT NULL
                AND last_version_refresh >= last_scrape_success - interval '1 hour'),
        format('last successful scrape %s, data_versions refreshed %s',
               coalesce(last_scrape_success::text, 'never'),
               coalesce(last_version_refresh::text, 'never'));

    -- 4. single_embedding_model.
    IF to_regclass('nlp.bill_embeddings') IS NOT NULL THEN
        SELECT count(DISTINCT model), string_agg(DISTINCT model, ', ')
          INTO n_models, model_list
          FROM nlp.bill_embeddings;
        RETURN QUERY SELECT
            'single_embedding_model'::text,
            coalesce(n_models, 0) <= 1,
            format('%s distinct model(s): %s',
                   coalesce(n_models, 0), coalesce(model_list, 'none'));
    ELSE
        RETURN QUERY SELECT 'single_embedding_model'::text, true,
                            'nlp.bill_embeddings absent — skipped'::text;
    END IF;

    -- 5. no_stuck_reconciles (v2 audit; persistent across swaps).
    IF to_regclass('ops.reconcile_runs') IS NOT NULL THEN
        SELECT count(*) INTO n_stuck
          FROM ops.reconcile_runs
         WHERE status = 'running'
           AND started_at < now() - interval '6 hours';
        RETURN QUERY SELECT
            'no_stuck_reconciles'::text,
            n_stuck = 0,
            format('%s reconcile_runs stuck in running > 6h', n_stuck);
    ELSE
        RETURN QUERY SELECT 'no_stuck_reconciles'::text, true,
                            'ops.reconcile_runs absent — skipped'::text;
    END IF;
END;
$$;

GRANT USAGE ON SCHEMA nlp_stage TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA nlp_stage TO PUBLIC;

COMMIT;
