-- 0010 — named data invariants, checked loudly (V2 refactor Phase 0).
--
-- The July 2026 incidents (107K orphaned nlp.bill_embeddings rows silently
-- failing every nightly verify_counts, ingest_runs rows stuck 'running', and a
-- stale ops.data_versions freezing the site's "Data updated" date) were all
-- invisible until someone hand-queried the database. ops.check_invariants()
-- gives each of those failure modes a name and a boolean, so the
-- invariant-check CronJob (k8s/*/invariant-check-cronjob.yaml) can fail
-- non-zero the day one goes red instead of weeks later.
--
-- Read-only: this migration only creates a function. It is deliberately
-- created without SET ROLE — on netcup the nlp/ops objects are owned by
-- postgres (bootstrap-era drift, see docs/BACKLOG.md E3), and 0004 already
-- demonstrated that SET ROLE csearch migrations fail against them.
-- See docs/V2-REFACTOR-PLAN.md, Phase 0.

BEGIN;

CREATE SCHEMA IF NOT EXISTS ops;

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
    -- 1. chunks_embeddings_1to1 — every embedding joins a chunk and vice
    --    versa. Orphaned embeddings sit in the HNSW index, surface in ANN
    --    scans, then vanish at the join: wasted index space and lost recall.
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

    -- 2. no_stuck_runs — a run that has claimed 'running' for over six hours
    --    is dead (killed pod, crashed process) and must be marked failed, or
    --    it masks every later failure of the same kind.
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

    -- 3. freshness_current — every successful scraper run must have bumped
    --    ops.data_versions (the site's "Data updated" date). A stale-pinned
    --    scraper image without ops.refresh_data_versions() froze this for
    --    days in July 2026. One hour of slack covers in-run ordering.
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

    -- 4. single_embedding_model — mixing vector spaces silently corrupts
    --    similarity ranking. Model swaps must go through the stage-schema
    --    blue/green path, never by interleaving models in one live table.
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
END;
$$;

COMMENT ON FUNCTION ops.check_invariants() IS
    'Named data invariants for the ingest pipeline; any ok=false row is an incident. Checked daily by the invariant-check CronJob.';

GRANT USAGE ON SCHEMA ops TO PUBLIC;
GRANT EXECUTE ON FUNCTION ops.check_invariants() TO PUBLIC;

COMMIT;
