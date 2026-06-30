-- 0002 — nlp schema: bill/vote chunks, embeddings, and HNSW indexes.
--
-- This is the authoritative definition of the semantic-search tables. It
-- matches the DDL that backend/nlp/project-tarp/upserter.py previously created
-- opportunistically at runtime; the upserter now validates against this shape
-- instead of creating it (see UPDATE.md and migration ownership in db/README.md).

BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;
CREATE SCHEMA IF NOT EXISTS nlp;

CREATE TABLE IF NOT EXISTS nlp.bill_chunks (
    id                     BIGSERIAL PRIMARY KEY,
    source_hash            TEXT NOT NULL UNIQUE,
    bill_id                TEXT NOT NULL,
    canonical_bill_id      TEXT NOT NULL,
    congress               INTEGER NOT NULL,
    bill_type              TEXT NOT NULL,
    bill_number            TEXT NOT NULL,
    chunk_type             TEXT NOT NULL,
    section_path           TEXT,
    title                  TEXT,
    body                   TEXT NOT NULL,
    token_count            INTEGER NOT NULL,
    source_version         TEXT,
    status                 TEXT,
    section_enum           TEXT,
    section_header         TEXT,
    chunk_index            INTEGER NOT NULL,
    original_chunk_index   INTEGER NOT NULL,
    document_text_hash     TEXT NOT NULL,
    section_text_hash      TEXT NOT NULL,
    document_text_hashes   JSONB NOT NULL DEFAULT '[]'::jsonb,
    document_aliases       JSONB,
    section_aliases        JSONB,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS nlp.bill_embeddings (
    chunk_id   BIGINT PRIMARY KEY REFERENCES nlp.bill_chunks(id) ON DELETE CASCADE,
    embedding  vector(1536) NOT NULL,
    model      TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bill_chunks_bill_id_idx ON nlp.bill_chunks (bill_id);
CREATE INDEX IF NOT EXISTS bill_chunks_canonical_bill_id_idx ON nlp.bill_chunks (canonical_bill_id);
CREATE INDEX IF NOT EXISTS bill_chunks_congress_idx ON nlp.bill_chunks (congress);
CREATE INDEX IF NOT EXISTS bill_chunks_bill_type_idx ON nlp.bill_chunks (bill_type);
CREATE INDEX IF NOT EXISTS bill_chunks_chunk_type_idx ON nlp.bill_chunks (chunk_type);
CREATE INDEX IF NOT EXISTS bill_chunks_source_hash_idx ON nlp.bill_chunks (source_hash);

CREATE INDEX IF NOT EXISTS bill_embeddings_embedding_hnsw_idx
    ON nlp.bill_embeddings
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 128);

-- Vote embeddings: defined here so the schema is complete and consistent even
-- though the production API does not yet expose vote semantic search.
CREATE TABLE IF NOT EXISTS nlp.vote_chunks (
    id           BIGSERIAL PRIMARY KEY,
    source_hash  TEXT NOT NULL UNIQUE,
    vote_id      TEXT NOT NULL,
    congress     INTEGER NOT NULL,
    chamber      TEXT NOT NULL,
    session      TEXT NOT NULL,
    number       INTEGER NOT NULL,
    vote_date    TIMESTAMPTZ,
    category     TEXT,
    vote_type    TEXT,
    question     TEXT,
    subject      TEXT,
    result       TEXT,
    bill_id      TEXT,
    body         TEXT NOT NULL,
    token_count  INTEGER NOT NULL,
    chunk_index  INTEGER NOT NULL DEFAULT 0,
    content_hash TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS nlp.vote_embeddings (
    chunk_id   BIGINT PRIMARY KEY REFERENCES nlp.vote_chunks(id) ON DELETE CASCADE,
    embedding  vector(1536) NOT NULL,
    model      TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS vote_chunks_vote_id_idx ON nlp.vote_chunks (vote_id);
CREATE INDEX IF NOT EXISTS vote_chunks_bill_id_idx ON nlp.vote_chunks (bill_id);
CREATE INDEX IF NOT EXISTS vote_chunks_congress_idx ON nlp.vote_chunks (congress);
CREATE INDEX IF NOT EXISTS vote_chunks_chamber_idx ON nlp.vote_chunks (chamber);
CREATE INDEX IF NOT EXISTS vote_chunks_date_idx ON nlp.vote_chunks (vote_date);
CREATE INDEX IF NOT EXISTS vote_chunks_source_hash_idx ON nlp.vote_chunks (source_hash);

CREATE INDEX IF NOT EXISTS vote_embeddings_embedding_hnsw_idx
    ON nlp.vote_embeddings
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 128);

COMMIT;
