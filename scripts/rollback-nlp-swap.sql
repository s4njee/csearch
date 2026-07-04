-- Roll back a corpus cutover made by scripts/swap-nlp-stage.sql:
-- nlp (v2) -> nlp_stage, nlp_prev (old corpus) -> nlp.
--
--   psql -v ON_ERROR_STOP=1 -f scripts/rollback-nlp-swap.sql
--
-- The v2 corpus is preserved as nlp_stage (not dropped), so a fixed stage can
-- be re-swapped without rebuilding. Restart the API afterwards, same as the
-- forward swap.

BEGIN;

DO $$
BEGIN
    IF to_regnamespace('nlp_prev') IS NULL THEN
        RAISE EXCEPTION 'rollback refused: nlp_prev does not exist — nothing to roll back to';
    END IF;
    IF to_regnamespace('nlp_stage') IS NOT NULL THEN
        RAISE EXCEPTION 'rollback refused: nlp_stage already exists — resolve the extra schema first';
    END IF;

    EXECUTE 'ALTER SCHEMA nlp RENAME TO nlp_stage';
    EXECUTE 'ALTER SCHEMA nlp_prev RENAME TO nlp';
    RAISE NOTICE 'rollback complete: previous corpus restored as nlp; v2 corpus retained as nlp_stage';
END $$;

COMMIT;
