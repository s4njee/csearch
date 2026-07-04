-- 0011 — enforce the chunk↔embedding FK that migration 0002 always intended.
--
-- 0002 defines nlp.bill_embeddings.chunk_id as PRIMARY KEY REFERENCES
-- nlp.bill_chunks(id) ON DELETE CASCADE — but netcup's live table predates the
-- migration chain (created by the old opportunistic upserter) and carries only
-- a unique index, no FK. Without the CASCADE, every per-bill delete+reinsert
-- in the upserter stranded that bill's old embeddings: 107,420 orphans by
-- July 2026, failing verify_counts on every nightly run, which blocked hash-
-- manifest promotion and forced a full ~3h reprocess every night.
--
-- Idempotent + self-healing by design:
--   * on a chain-built DB the DELETE matches 0 rows and the FK already exists
--     (no-op);
--   * on a drifted DB it purges orphans first (VALIDATE would fail otherwise)
--     then installs the same FK 0002 declares, with 0002's default name.
-- Orphaned embeddings are unreachable garbage — retrieval joins embeddings to
-- chunks, so these rows only bloat the HNSW index and eat ANN candidates.

BEGIN;

DO $$
BEGIN
    IF to_regclass('nlp.bill_embeddings') IS NULL
       OR to_regclass('nlp.bill_chunks') IS NULL THEN
        RETURN;  -- nlp tables absent in this environment
    END IF;

    -- 1. Purge orphans (prerequisite for FK validation; 0 rows on healthy DBs).
    DELETE FROM nlp.bill_embeddings e
     WHERE NOT EXISTS (SELECT 1 FROM nlp.bill_chunks c WHERE c.id = e.chunk_id);

    -- 2. Install the FK if this table predates it.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'nlp.bill_embeddings'::regclass
          AND contype = 'f'
          AND confrelid = 'nlp.bill_chunks'::regclass
    ) THEN
        ALTER TABLE nlp.bill_embeddings
            ADD CONSTRAINT bill_embeddings_chunk_id_fkey
            FOREIGN KEY (chunk_id) REFERENCES nlp.bill_chunks(id)
            ON DELETE CASCADE;
    END IF;
END $$;

COMMIT;
