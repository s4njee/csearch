-- Schema + vector smoke test. Run after migrations and fixtures:
--   psql -v ON_ERROR_STOP=1 -f db/smoke.sql
-- Every check RAISEs on failure so the script exits non-zero in CI.

DO $$
DECLARE
    n integer;
    query_vec vector;
    nearest text;
    last_run text;
BEGIN
    -- Core counts from the fixture corpus.
    SELECT count(*) INTO n FROM bills;
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 bills, got %', n; END IF;

    SELECT count(*) INTO n FROM nlp.bill_chunks;
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 nlp chunks, got %', n; END IF;

    SELECT count(*) INTO n FROM nlp.bill_embeddings;
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 nlp embeddings, got %', n; END IF;

    -- Vector nearest-neighbor: a query along axis 1 must retrieve hr42-119,
    -- whose fixture embedding is the axis-1 unit vector. Proves the HNSW/pgvector
    -- retrieval path end to end without any OpenAI call.
    query_vec := (
        SELECT ('[' || string_agg(CASE WHEN g = 1 THEN '1' ELSE '0' END, ',') || ']')::vector
        FROM generate_series(1, 1536) g
    );
    SELECT c.bill_id INTO nearest
    FROM nlp.bill_chunks c
    JOIN nlp.bill_embeddings e ON e.chunk_id = c.id
    ORDER BY e.embedding <=> query_vec
    LIMIT 1;
    IF nearest <> 'hr42-119' THEN
        RAISE EXCEPTION 'vector search returned %, expected hr42-119', nearest;
    END IF;

    -- Coverage: every fixture bill has a chunk, so none are missing.
    SELECT count(*) INTO n
    FROM public.bills b
    WHERE NOT EXISTS (
        SELECT 1 FROM nlp.bill_chunks c
        WHERE c.bill_type = b.billtype
          AND c.bill_number = b.billnumber::text
          AND c.congress = b.congress
    );
    IF n <> 0 THEN RAISE EXCEPTION 'expected 0 bills missing chunks, got %', n; END IF;

    -- Ingest audit row is present and successful.
    SELECT status INTO last_run FROM nlp.ingest_runs ORDER BY started_at DESC LIMIT 1;
    IF last_run IS DISTINCT FROM 'success' THEN
        RAISE EXCEPTION 'expected last ingest run success, got %', last_run;
    END IF;

    -- Full-text search function returns the broadband bill for a topical query.
    SELECT count(*) INTO n FROM search_bills('broadband');
    IF n < 1 THEN RAISE EXCEPTION 'search_bills(broadband) returned no rows'; END IF;

    RAISE NOTICE 'DB smoke test passed.';
END
$$;
