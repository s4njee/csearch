-- 0009 — cheap data-version contract for edge cache invalidation.
--
-- The Cloudflare API cache asks the origin for compact data versions. Those
-- versions must be cheap to read; table-wide MAX() scans add seconds of latency
-- to otherwise cached edge requests. This migration adds:
--   * an update_date index for bill update freshness,
--   * an optional nlp.bill_chunks(created_at) index when NLP tables exist,
--   * a tiny ops.data_versions table maintained by the scraper.

BEGIN;

CREATE SCHEMA IF NOT EXISTS ops;

CREATE INDEX IF NOT EXISTS bills_update_date_idx
    ON public.bills (update_date DESC NULLS LAST);

DO $$
BEGIN
    IF to_regclass('nlp.bill_chunks') IS NOT NULL THEN
        CREATE INDEX IF NOT EXISTS bill_chunks_created_at_idx
            ON nlp.bill_chunks (created_at DESC);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ops.data_versions (
    domain       text PRIMARY KEY,
    version      text,
    refreshed_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION ops.refresh_data_versions()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    bill_updates_v text;
    bill_actions_v text;
    bills_v text;
    votes_v text;
    semantic_v text;
    explore_v text;
    general_v text;
BEGIN
    SELECT update_date::text
      INTO bill_updates_v
      FROM public.bills
     WHERE update_date IS NOT NULL
     ORDER BY update_date DESC NULLS LAST
     LIMIT 1;

    SELECT latest_action_date::text
      INTO bill_actions_v
      FROM public.bills
     WHERE latest_action_date IS NOT NULL
     ORDER BY latest_action_date DESC NULLS LAST
     LIMIT 1;

    SELECT max(v)
      INTO bills_v
      FROM (VALUES (bill_updates_v), (bill_actions_v)) AS versions(v)
     WHERE v IS NOT NULL;

    SELECT votedate::text
      INTO votes_v
      FROM public.votes
     WHERE votedate IS NOT NULL
     ORDER BY votedate DESC NULLS LAST
     LIMIT 1;

    IF to_regclass('nlp.bill_chunks') IS NOT NULL THEN
        EXECUTE
            'SELECT created_at::text FROM nlp.bill_chunks
              WHERE created_at IS NOT NULL
              ORDER BY created_at DESC NULLS LAST
              LIMIT 1'
            INTO semantic_v;
    END IF;

    SELECT max(v)
      INTO explore_v
      FROM (VALUES (bills_v), (votes_v)) AS versions(v)
     WHERE v IS NOT NULL;

    SELECT max(v)
      INTO general_v
      FROM (VALUES (bills_v), (votes_v), (explore_v), (semantic_v)) AS versions(v)
     WHERE v IS NOT NULL;

    INSERT INTO ops.data_versions (domain, version, refreshed_at)
    SELECT domain, version, now()
      FROM (VALUES
          ('bill_updates', bill_updates_v),
          ('bill_actions', bill_actions_v),
          ('bills', bills_v),
          ('votes', votes_v),
          ('semantic', semantic_v),
          ('explore', explore_v),
          ('general', general_v)
      ) AS computed(domain, version)
     WHERE version IS NOT NULL
    ON CONFLICT (domain) DO UPDATE SET
        version = excluded.version,
        refreshed_at = excluded.refreshed_at;
END;
$$;

SELECT ops.refresh_data_versions();

COMMIT;
