-- Migration 0008: canonical bill identity — generated bill_uid column + FK seam
--
-- §2 of docs/CRITICISMS2.md:
--   "nlp joins to public.bills by casting billnumber::text, with no foreign key"
--
-- This migration:
--   1. Adds a generated stored column bill_uid to public.bills_default (the
--      catch-all partition), seeded as billtype || billnumber::text || '-' || congress::text.
--      The column is GENERATED ALWAYS AS STORED so backfill is automatic and the
--      value cannot drift from its components.
--   2. Adds a unique index on bill_uid so the join can use an index scan instead
--      of a per-row cast. NOTE: Because bills is partitioned, the unique constraint
--      is on each partition, not globally. Global uniqueness is already guaranteed
--      by the PK (billtype, billnumber, congress).
--   3. Creates a partial index on nlp.bill_chunks(canonical_bill_id) if the nlp
--      schema is present, so the orphan query and future FK validation are fast.
--   4. Documents the FK seam: a full FOREIGN KEY constraint with NOT VALID /
--      VALIDATE CONSTRAINT follows as a separate admin step (see comment below)
--      because VALIDATE CONSTRAINT can take minutes on a large table and should
--      be run in a maintenance window with LOCK TIMEOUT protection.
--
-- After running this migration:
--   • Update _SEARCH_SQL in routes/semantic.py to use bill_uid = canonical_bill_id
--     instead of billnumber::text = bill_number (removes the per-row cast).
--   • Run the coverage query to confirm orphan count = 0.
--   • Then run the FK validation step in a maintenance window:
--       ALTER TABLE nlp.bill_chunks
--         ADD CONSTRAINT fk_chunks_bill_uid
--         FOREIGN KEY (canonical_bill_id) REFERENCES public.bills_default(bill_uid)
--         NOT VALID;
--       ALTER TABLE nlp.bill_chunks VALIDATE CONSTRAINT fk_chunks_bill_uid;

BEGIN;

INSERT INTO schema_migrations (version, description)
VALUES ('0008', 'bill_uid_canonical_identity')
ON CONFLICT (version) DO NOTHING;

-- Add generated bill_uid to the default partition.
-- If bills is not partitioned in this database, apply to bills directly.
DO $$
BEGIN
    -- Try the partitioned path first (production).
    IF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'bills_default'
    ) THEN
        ALTER TABLE public.bills_default
            ADD COLUMN IF NOT EXISTS bill_uid text
            GENERATED ALWAYS AS (billtype || billnumber::text || '-' || congress::text) STORED;

        CREATE UNIQUE INDEX IF NOT EXISTS bills_default_bill_uid_uidx
            ON public.bills_default (bill_uid);

    -- Fallback: unpartitioned bills table (local dev / CI).
    ELSIF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'bills'
          AND c.relkind = 'r'  -- plain table, not partitioned
    ) THEN
        ALTER TABLE public.bills
            ADD COLUMN IF NOT EXISTS bill_uid text
            GENERATED ALWAYS AS (billtype || billnumber::text || '-' || congress::text) STORED;

        CREATE UNIQUE INDEX IF NOT EXISTS bills_bill_uid_uidx
            ON public.bills (bill_uid);
    END IF;
END $$;

-- Index canonical_bill_id on nlp.bill_chunks for the orphan check and future FK.
-- Wrapped in a DO block so the migration applies cleanly even when the nlp
-- schema has not been created yet (bills-only databases).
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'nlp' AND c.relname = 'bill_chunks'
    ) THEN
        CREATE INDEX IF NOT EXISTS bill_chunks_canonical_bill_id_idx
            ON nlp.bill_chunks (canonical_bill_id);
    END IF;
END $$;

COMMIT;

-- ─── MAINTENANCE WINDOW: run these separately after validating orphan count = 0 ───
--
-- ALTER TABLE nlp.bill_chunks
--     ADD CONSTRAINT fk_chunks_bill_uid
--     FOREIGN KEY (canonical_bill_id) REFERENCES public.bills_default(bill_uid)
--     NOT VALID;
--
-- SET lock_timeout = '5s';
-- ALTER TABLE nlp.bill_chunks VALIDATE CONSTRAINT fk_chunks_bill_uid;
-- RESET lock_timeout;
--
-- After FK is validated, update _SEARCH_SQL in routes/semantic.py:
--   Change:  AND b.billnumber::text = r.bill_number
--   To:      AND b.bill_uid = r.canonical_bill_id
-- ──────────────────────────────────────────────────────────────────────────────────
