-- Migration 0007: index on nlp.bill_embeddings.model
--
-- The retrieval query (routes/semantic.py _SEARCH_SQL) now filters
-- WHERE model = $6 so it only scans embeddings for the active model,
-- preventing incompatible vector spaces from being mixed silently
-- (§3 docs/CRITICISMS2.md).
--
-- Without this index every retrieval query would require a sequential
-- scan on bill_embeddings to apply the model predicate before the HNSW
-- ANN step.  With a partial B-tree index on model the planner can
-- restrict to the relevant set first, then run the ANN scan.
--
-- NOTE: If you run multiple embedding models in parallel (e.g. during a
-- blue/green model migration), add a partial HNSW index per model table
-- or per-model partition instead of relying on this column index.

BEGIN;

-- Version tracking is owned by db/migrate.py (it records each applied version
-- in public.schema_migrations). Migrations must not self-record — that table
-- has no "description" column, so the prior INSERT failed the whole migration.

-- Index so WHERE model = $1 on nlp.bill_embeddings can filter before ANN.
CREATE INDEX IF NOT EXISTS bill_embeddings_model_idx
    ON nlp.bill_embeddings (model);

-- Also index canonical_bill_id on bill_chunks for the future FK join
-- (§2 CRITICISMS2.md — full FK lands in migration 0008).
CREATE INDEX IF NOT EXISTS bill_chunks_canonical_bill_id_idx
    ON nlp.bill_chunks (canonical_bill_id);

COMMIT;
