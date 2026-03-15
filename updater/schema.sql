-- Fresh database bootstrap for the csearch updater.
--
-- This file is intended to run once against an empty Postgres database, e.g.
-- via the official postgres image's /docker-entrypoint-initdb.d/ mechanism on
-- first container start.

BEGIN;

CREATE TABLE bills (
    billid              text,
    billnumber          text NOT NULL,
    billtype            text NOT NULL,
    introducedat        text,
    congress            text NOT NULL,
    summary_date        text,
    summary_text        text,
    sponsor_bioguide_id text,
    sponsor_name        text,
    sponsor_state       text,
    sponsor_party       text,
    origin_chamber      text,
    policy_area         text,
    update_date         text,
    latest_action_id    bigint,
    latest_action_date  text,
    statusat            text NOT NULL,
    shorttitle          text,
    officialtitle       text,
    CONSTRAINT bill_pkey PRIMARY KEY (billtype, billnumber, congress)
) PARTITION BY LIST (billtype);

CREATE TABLE bills_s PARTITION OF bills FOR VALUES IN ('s');
CREATE TABLE bills_hr PARTITION OF bills FOR VALUES IN ('hr');
CREATE TABLE bills_hconres PARTITION OF bills FOR VALUES IN ('hconres');
CREATE TABLE bills_hjres PARTITION OF bills FOR VALUES IN ('hjres');
CREATE TABLE bills_hres PARTITION OF bills FOR VALUES IN ('hres');
CREATE TABLE bills_sconres PARTITION OF bills FOR VALUES IN ('sconres');
CREATE TABLE bills_sjres PARTITION OF bills FOR VALUES IN ('sjres');
CREATE TABLE bills_sres PARTITION OF bills FOR VALUES IN ('sres');

-- Separate generated tsvector columns preserve the existing bill-type-specific
-- search pattern while sourcing text from the normalized summary_text column.
ALTER TABLE bills ADD COLUMN s_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills ADD COLUMN hr_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills ADD COLUMN hconres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills ADD COLUMN hjres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills ADD COLUMN hres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills ADD COLUMN sconres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills ADD COLUMN sjres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills ADD COLUMN sres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;

-- search_document is the general-purpose ranked search vector for product and
-- agent use. The older per-billtype vectors remain for compatibility with any
-- code that still routes search by bill family.
ALTER TABLE bills ADD COLUMN search_document tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(shorttitle, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(officialtitle, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(summary_text, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(sponsor_name, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(policy_area, '')), 'C')
) STORED;

CREATE INDEX s_ts_idx ON bills USING GIN (s_ts);
CREATE INDEX hr_ts_idx ON bills USING GIN (hr_ts);
CREATE INDEX hconres_ts_idx ON bills USING GIN (hconres_ts);
CREATE INDEX hjres_ts_idx ON bills USING GIN (hjres_ts);
CREATE INDEX hres_ts_idx ON bills USING GIN (hres_ts);
CREATE INDEX sconres_ts_idx ON bills USING GIN (sconres_ts);
CREATE INDEX sjres_ts_idx ON bills USING GIN (sjres_ts);
CREATE INDEX sres_ts_idx ON bills USING GIN (sres_ts);
CREATE INDEX bills_search_document_idx ON bills USING GIN (search_document);

-- Recency-oriented browse queries order by these two columns together.
CREATE INDEX bills_statusat_update_date_idx
    ON bills (statusat DESC, update_date DESC NULLS LAST);

CREATE INDEX bills_missing_metadata_idx
    ON bills (congress, billtype, billnumber)
    WHERE shorttitle IS NULL
       OR officialtitle IS NULL
       OR sponsor_name IS NULL
       OR summary_text IS NULL
       OR policy_area IS NULL;

CREATE TABLE bill_actions (
    id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    billtype           text NOT NULL,
    billnumber         text NOT NULL,
    congress           text NOT NULL,
    acted_at           text NOT NULL,
    action_text        text,
    action_type        text,
    action_code        text,
    source_system_code text,
    CONSTRAINT bill_actions_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX bill_actions_id_bill_lookup_idx
    ON bill_actions (id, billtype, billnumber, congress);

CREATE INDEX bill_actions_bill_lookup_idx
    ON bill_actions (billtype, billnumber, congress, acted_at);

ALTER TABLE bills
    ADD CONSTRAINT bills_latest_action_fkey
        FOREIGN KEY (latest_action_id, billtype, billnumber, congress)
        REFERENCES bill_actions (id, billtype, billnumber, congress)
        ON DELETE SET NULL;

CREATE TABLE bill_cosponsors (
    billtype              text NOT NULL,
    billnumber            text NOT NULL,
    congress              text NOT NULL,
    bioguide_id           text NOT NULL,
    full_name             text,
    state                 text,
    party                 text,
    sponsorship_date      text,
    is_original_cosponsor boolean,
    CONSTRAINT bill_cosponsors_pkey PRIMARY KEY (billtype, billnumber, congress, bioguide_id),
    CONSTRAINT bill_cosponsors_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE
);

CREATE TABLE bill_committees (
    billtype       text NOT NULL,
    billnumber     text NOT NULL,
    congress       text NOT NULL,
    committee_code text NOT NULL,
    committee_name text,
    chamber        text,
    CONSTRAINT bill_committees_pkey PRIMARY KEY (billtype, billnumber, congress, committee_code),
    CONSTRAINT bill_committees_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE
);

CREATE INDEX bill_committees_code_idx
    ON bill_committees (committee_code, congress);

CREATE TABLE bill_subjects (
    billtype   text NOT NULL,
    billnumber text NOT NULL,
    congress   text NOT NULL,
    subject    text NOT NULL,
    CONSTRAINT bill_subjects_pkey PRIMARY KEY (billtype, billnumber, congress, subject),
    CONSTRAINT bill_subjects_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE
);

CREATE INDEX bill_subjects_subject_idx
    ON bill_subjects (subject, congress);

CREATE TABLE votes (
    voteid      text NOT NULL PRIMARY KEY,
    bill_type   text,
    bill_number text,
    congress    text,
    votenumber  text,
    votedate    text,
    question    text,
    result      text,
    votesession text,
    chamber     text,
    source_url  text,
    votetype    text
);

ALTER TABLE votes ADD COLUMN search_document tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(question, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(result, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(votetype, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(chamber, '')), 'D')
) STORED;

CREATE INDEX votes_votedate_idx ON votes (votedate DESC);
CREATE INDEX votes_congress_idx ON votes (congress);
CREATE INDEX votes_chamber_idx ON votes (chamber);
CREATE INDEX votes_search_document_idx ON votes USING GIN (search_document);

CREATE TABLE vote_members (
    voteid       text NOT NULL,
    bioguide_id  text NOT NULL,
    display_name text,
    party        text,
    state        text,
    position     text NOT NULL,
    CONSTRAINT vote_members_pkey PRIMARY KEY (voteid, bioguide_id),
    CONSTRAINT vote_members_vote_fkey
        FOREIGN KEY (voteid)
        REFERENCES votes (voteid)
        ON DELETE CASCADE
);

CREATE INDEX vote_members_notvoting_idx
    ON vote_members (bioguide_id)
    WHERE position = 'notvoting';

CREATE OR REPLACE FUNCTION search_bills(
    search_query text,
    filter_billtype text DEFAULT NULL,
    filter_congress text DEFAULT NULL,
    result_limit integer DEFAULT 50
) RETURNS TABLE (
    billtype text,
    billnumber text,
    congress text,
    shorttitle text,
    officialtitle text,
    summary_text text,
    sponsor_name text,
    policy_area text,
    rank real
) LANGUAGE sql STABLE AS $$
    WITH query AS (
        SELECT websearch_to_tsquery('english', search_query) AS ts_query
    )
    SELECT
        b.billtype,
        b.billnumber,
        b.congress,
        b.shorttitle,
        b.officialtitle,
        b.summary_text,
        b.sponsor_name,
        b.policy_area,
        ts_rank_cd(b.search_document, query.ts_query) AS rank
    FROM bills b
    CROSS JOIN query
    WHERE (filter_billtype IS NULL OR b.billtype = filter_billtype)
      AND (filter_congress IS NULL OR b.congress = filter_congress)
      AND b.search_document @@ query.ts_query
    ORDER BY rank DESC, b.statusat DESC, b.billtype, b.billnumber
    LIMIT GREATEST(result_limit, 1);
$$;

CREATE OR REPLACE FUNCTION search_votes(
    search_query text,
    filter_congress text DEFAULT NULL,
    filter_chamber text DEFAULT NULL,
    result_limit integer DEFAULT 50
) RETURNS TABLE (
    voteid text,
    congress text,
    chamber text,
    votetype text,
    question text,
    result text,
    votedate text,
    rank real
) LANGUAGE sql STABLE AS $$
    WITH query AS (
        SELECT websearch_to_tsquery('english', search_query) AS ts_query
    )
    SELECT
        v.voteid,
        v.congress,
        v.chamber,
        v.votetype,
        v.question,
        v.result,
        v.votedate,
        ts_rank_cd(v.search_document, query.ts_query) AS rank
    FROM votes v
    CROSS JOIN query
    WHERE (filter_congress IS NULL OR v.congress = filter_congress)
      AND (filter_chamber IS NULL OR v.chamber = filter_chamber)
      AND v.search_document @@ query.ts_query
    ORDER BY rank DESC, v.votedate DESC, v.voteid DESC
    LIMIT GREATEST(result_limit, 1);
$$;

COMMIT;
