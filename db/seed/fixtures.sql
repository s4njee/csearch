-- Tiny deterministic fixture corpus for local dev and CI smoke tests.
--
-- 2 bills, 1 vote, 2 NLP chunks with deterministic fake 1536-dim embeddings,
-- and one successful ingest run. No secrets and no OpenAI calls are required to
-- exercise the full semantic-search path against this data. Apply after the
-- migrations: psql -f db/seed/fixtures.sql
--
-- Deterministic "fake" vectors are unit vectors pointing along a single axis so
-- cosine similarity between them is predictable in tests.

BEGIN;

INSERT INTO committees (committee_code, committee_name, chamber) VALUES
    ('HSAG', 'House Committee on Agriculture', 'house'),
    ('SSEV', 'Senate Committee on Environment and Public Works', 'senate')
ON CONFLICT (committee_code) DO NOTHING;

INSERT INTO bills (
    billid, billnumber, billtype, congress, introducedat,
    sponsor_name, sponsor_party, sponsor_state, origin_chamber, policy_area,
    update_date, latest_action_date, bill_status, statusat, shorttitle, officialtitle
) VALUES
    ('hr42-119', 42, 'hr', 119, '2025-01-15',
     'Jane Doe', 'D', 'CA', 'House', 'Agriculture and Food',
     '2025-03-01', '2025-03-01', 'introduced', '2025-03-01',
     'Rural Broadband Investment Act', 'A bill to expand rural broadband access'),
    ('s100-119', 100, 's', 119, '2025-02-01',
     'John Smith', 'R', 'TX', 'Senate', 'Environmental Protection',
     '2025-02-20', '2025-02-20', 'introduced', '2025-02-20',
     'Clean Water Restoration Act', 'A bill to restore clean water protections')
ON CONFLICT (billtype, billnumber, congress) DO NOTHING;

INSERT INTO bill_committees (billtype, billnumber, congress, committee_code) VALUES
    ('hr', 42, 119, 'HSAG'),
    ('s', 100, 119, 'SSEV')
ON CONFLICT DO NOTHING;

INSERT INTO votes (voteid, bill_type, bill_number, congress, votenumber, votedate, question, result, votesession, chamber, votetype)
VALUES ('h42-119.2025', 'hr', 42, 119, 1, '2025-02-15', 'On Passage', 'Passed', '2025', 'h', 'YEA-AND-NAY')
ON CONFLICT (voteid) DO NOTHING;

INSERT INTO vote_members (voteid, bioguide_id, display_name, party, state, position)
VALUES ('h42-119.2025', 'D000001', 'Jane Doe', 'D', 'CA', 'yea')
ON CONFLICT DO NOTHING;

-- NLP chunks + deterministic embeddings. axis 0 -> bill hr42, axis 1 -> bill s100.
INSERT INTO nlp.bill_chunks (
    source_hash, bill_id, canonical_bill_id, congress, bill_type, bill_number,
    chunk_type, body, token_count, chunk_index, original_chunk_index,
    document_text_hash, section_text_hash
) VALUES
    ('fixture-hash-hr42', 'hr42-119', 'hr42-119', 119, 'hr', '42',
     'section', 'This Act expands rural broadband investment and access.', 11, 0, 0,
     'doc-hash-hr42', 'sec-hash-hr42'),
    ('fixture-hash-s100', 's100-119', 's100-119', 119, 's', '100',
     'section', 'This Act restores clean water protections nationwide.', 9, 0, 0,
     'doc-hash-s100', 'sec-hash-s100')
ON CONFLICT (source_hash) DO NOTHING;

INSERT INTO nlp.bill_embeddings (chunk_id, embedding, model)
SELECT c.id,
       (SELECT '[' || string_agg(CASE WHEN g = (CASE c.bill_id WHEN 'hr42-119' THEN 1 ELSE 2 END) THEN '1' ELSE '0' END, ',') || ']'
        FROM generate_series(1, 1536) g)::vector,
       'text-embedding-3-small'
FROM nlp.bill_chunks c
WHERE c.source_hash IN ('fixture-hash-hr42', 'fixture-hash-s100')
ON CONFLICT (chunk_id) DO NOTHING;

INSERT INTO nlp.ingest_runs (
    run_id, git_sha, congress, source_root, status,
    input_bill_count, changed_bill_count, chunk_count, token_count,
    embedding_model, embedding_dimensions, shard_count, upserted_chunk_count,
    finished_at
) VALUES (
    'fixture-run-0001', 'fixturesha', 119, '/fixtures', 'success',
    2, 2, 2, 20, 'text-embedding-3-small', 1536, 1, 2, now()
) ON CONFLICT (run_id) DO NOTHING;

INSERT INTO zip_districts (zcta, state_fips, state_abbr, cd) VALUES
    ('90210', '06', 'CA', 30)
ON CONFLICT DO NOTHING;

COMMIT;
