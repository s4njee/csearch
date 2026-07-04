-- 0013 — drop UNIQUE (bill_uid, chunk_index) from the staged v2 corpus.
--
-- Checked against the real netcup corpus before seeding (V2 Phase 3): congress
-- 119 has 59,773 duplicate (canonical_bill_id, chunk_index) groups, because a
-- canonical bill legitimately carries chunks from MULTIPLE document versions
-- (introduced/engrossed/enrolled), each with its own chunk_index sequence.
-- The constraint in 0012 encoded an assumption the corpus does not satisfy.
-- source_hash (globally unique in the real data, and already UNIQUE here) is
-- the row identity; per-bill grouping is bill_uid without an index contract.

BEGIN;

DO $$
BEGIN
    IF to_regclass('nlp_stage.chunks') IS NOT NULL THEN
        ALTER TABLE nlp_stage.chunks
            DROP CONSTRAINT IF EXISTS chunks_bill_chunk_unique;
    END IF;
    -- If the swap has already happened in this environment, the table lives
    -- under nlp instead.
    IF to_regclass('nlp.chunks') IS NOT NULL THEN
        ALTER TABLE nlp.chunks
            DROP CONSTRAINT IF EXISTS chunks_bill_chunk_unique;
    END IF;
END $$;

COMMIT;
