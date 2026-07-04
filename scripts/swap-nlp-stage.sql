-- Atomic corpus cutover: nlp -> nlp_prev, nlp_stage -> nlp.
--
--   psql -v ON_ERROR_STOP=1 -f scripts/swap-nlp-stage.sql
--
-- Used for the v1->v2 migration, the freya green-env bootstrap, and any
-- future staged rebuild (embedding-model swap, HNSW rebuild). Guards refuse
-- the obviously-wrong swaps; the rename pair is transactional, so the swap is
-- all-or-nothing and rollback is scripts/rollback-nlp-swap.sql.
--
-- After swapping in production, restart the API deployment
-- (kubectl rollout restart deploy/csearch-api) to clear cached plans.

BEGIN;

DO $$
DECLARE
    n bigint;
BEGIN
    IF to_regnamespace('nlp_stage') IS NULL THEN
        RAISE EXCEPTION 'swap refused: schema nlp_stage does not exist';
    END IF;
    IF to_regnamespace('nlp') IS NULL THEN
        RAISE EXCEPTION 'swap refused: schema nlp does not exist';
    END IF;
    IF to_regnamespace('nlp_prev') IS NOT NULL THEN
        RAISE EXCEPTION 'swap refused: nlp_prev already exists — previous swap not cleaned up (DROP SCHEMA nlp_prev CASCADE once satisfied, or roll back first)';
    END IF;
    IF to_regclass('nlp_stage.chunks') IS NULL THEN
        RAISE EXCEPTION 'swap refused: nlp_stage.chunks missing — stage schema is not a v2 corpus';
    END IF;
    EXECUTE 'SELECT count(*) FROM nlp_stage.chunks' INTO n;
    IF n = 0 THEN
        RAISE EXCEPTION 'swap refused: nlp_stage.chunks is empty — swapping would blank retrieval. Seed/reconcile the stage first.';
    END IF;

    EXECUTE 'ALTER SCHEMA nlp RENAME TO nlp_prev';
    EXECUTE 'ALTER SCHEMA nlp_stage RENAME TO nlp';
    RAISE NOTICE 'swap complete: nlp is now the v2 corpus (% chunks); previous corpus retained as nlp_prev', n;
END $$;

COMMIT;
