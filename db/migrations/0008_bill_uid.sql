-- Migration 0008: canonical bill identity — generated bill_uid column + FK seam
--
-- §2 of docs/CRITICISMS2.md:
--   "nlp joins to public.bills by casting billnumber::text, with no foreign key"
--
-- This migration:
--   1. Adds a generated stored column bill_uid to public.bills, seeded as
--      billtype || billnumber::text || '-' || congress::text. bills is
--      LIST-partitioned by congress (see 0001), so the column is added to the
--      partitioned PARENT — ADD COLUMN on a partition (e.g. bills_default) raises
--      "cannot add column to a partition". Adding it to the parent cascades the
--      generated column to every partition. It is GENERATED ALWAYS AS STORED so
--      backfill is automatic and the value cannot drift from its components.
--   2. Adds an index on bill_uid so the join can use an index scan instead of a
--      per-row cast. It is non-unique: global uniqueness is already guaranteed by
--      the PK (billtype, billnumber, congress), and a UNIQUE index on a
--      partitioned table would have to include the partition key (congress). A
--      plain index on the parent cascades to every partition (where the in-range
--      bills actually live — the old build indexed only bills_default, the
--      catch-all partition, which holds no in-range bills).
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

-- Version tracking is owned by db/migrate.py (see 0007 note); do not self-record.

-- Add the generated bill_uid to the partitioned parent public.bills. This works
-- whether bills is partitioned (production — the column cascades to every
-- partition) or a plain table (local dev / CI), so no branching is needed.
-- ADD COLUMN must NOT target a partition (e.g. public.bills_default): Postgres
-- raises "cannot add column to a partition".
ALTER TABLE public.bills
    ADD COLUMN IF NOT EXISTS bill_uid text
    GENERATED ALWAYS AS (billtype || billnumber::text || '-' || congress::text) STORED;

-- Non-unique index on the parent; cascades to every partition. See note (2) in
-- the header for why this is not UNIQUE.
CREATE INDEX IF NOT EXISTS bills_bill_uid_idx
    ON public.bills (bill_uid);

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
-- NOTE: a real FK needs a UNIQUE target, but bills_bill_uid_idx is non-unique
-- and bills is partitioned (an FK cannot reference a partitioned table on PG<17,
-- nor a single partition usefully). Treat this as a documented future seam: to
-- enforce it you would first add a UNIQUE constraint on (billtype, billnumber,
-- congress) — already the PK — and reference that, or add a per-partition unique
-- index on bill_uid. The bill_uid column + index below already remove the
-- per-row cast, which is the immediate win; the FK is optional integrity.
--
-- ALTER TABLE nlp.bill_chunks
--     ADD CONSTRAINT fk_chunks_bill_uid
--     FOREIGN KEY (canonical_bill_id) REFERENCES public.bills(bill_uid)
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
