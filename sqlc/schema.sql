-- Bills table: JSONB columns replaced with scalar fields; new fields added
CREATE TABLE bills(
    billid              text,
    billnumber          text NOT NULL,
    billtype            text NOT NULL,
    introducedat        text,
    congress            text NOT NULL,
    -- flattened from summary jsonb
    summary_date        text,
    summary_text        text,
    -- flattened from sponsors jsonb (always exactly one sponsor per bill)
    sponsor_bioguide_id text,
    sponsor_name        text,
    sponsor_state       text,
    sponsor_party       text,
    -- new fields from XML
    origin_chamber      text,
    policy_area         text,
    update_date         text,
    statusat            text NOT NULL,
    shorttitle          text,
    officialtitle       text,
    CONSTRAINT bill_pkey PRIMARY KEY (billtype, billnumber, congress)
) PARTITION BY LIST (billtype);

CREATE TABLE bills_s PARTITION OF bills FOR VALUES in ('s');
CREATE INDEX ON bills_s (billtype);

CREATE TABLE bills_hr PARTITION OF bills FOR VALUES in ('hr');
CREATE INDEX ON bills_hr (billtype);

CREATE TABLE bills_hconres PARTITION OF bills FOR VALUES in ('hconres');
CREATE INDEX ON bills_hconres (billtype);

CREATE TABLE bills_hjres PARTITION OF bills FOR VALUES in ('hjres');
CREATE INDEX ON bills_hjres (billtype);

CREATE TABLE bills_hres PARTITION OF bills FOR VALUES in ('hres');
CREATE INDEX ON bills_hres (billtype);

CREATE TABLE bills_sconres PARTITION OF bills FOR VALUES in ('sconres');
CREATE INDEX ON bills_sconres (billtype);

CREATE TABLE bills_sjres PARTITION OF bills FOR VALUES in ('sjres');
CREATE INDEX ON bills_sjres (billtype);

CREATE TABLE bills_sres PARTITION OF bills FOR VALUES in ('sres');
CREATE INDEX ON bills_sres (billtype);

-- Full-text search vectors (updated to use summary_text column)
ALTER TABLE bills ADD COLUMN s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX s_ts_idx ON bills USING GIN (s_ts);

ALTER TABLE bills ADD COLUMN hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX hr_ts_idx ON bills USING GIN (hr_ts);

ALTER TABLE bills ADD COLUMN hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX hconres_ts_idx ON bills USING GIN (hconres_ts);

ALTER TABLE bills ADD COLUMN hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX hjres_ts_idx ON bills USING GIN (hjres_ts);

ALTER TABLE bills ADD COLUMN hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX hres_ts_idx ON bills USING GIN (hres_ts);

ALTER TABLE bills ADD COLUMN sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX sconres_ts_idx ON bills USING GIN (sconres_ts);

ALTER TABLE bills ADD COLUMN sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX sjres_ts_idx ON bills USING GIN (sjres_ts);

ALTER TABLE bills ADD COLUMN sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary_text,''))) STORED;
CREATE INDEX sres_ts_idx ON bills USING GIN (sres_ts);

-- Actions: one row per action per bill (replaces actions jsonb)
CREATE TABLE bill_actions (
    billtype            text NOT NULL,
    billnumber          text NOT NULL,
    congress            text NOT NULL,
    acted_at            text NOT NULL,
    action_text         text,
    action_type         text,
    action_code         text,
    source_system_code  text
);
CREATE INDEX ON bill_actions (billtype, billnumber, congress);

-- Cosponsors: one row per cosponsor per bill (replaces cosponsors jsonb)
CREATE TABLE bill_cosponsors (
    billtype                text NOT NULL,
    billnumber              text NOT NULL,
    congress                text NOT NULL,
    bioguide_id             text NOT NULL,
    full_name               text,
    state                   text,
    party                   text,
    sponsorship_date        text,
    is_original_cosponsor   boolean,
    PRIMARY KEY (billtype, billnumber, congress, bioguide_id)
);

-- Committee assignments per bill (new, not previously captured)
CREATE TABLE bill_committees (
    billtype        text NOT NULL,
    billnumber      text NOT NULL,
    congress        text NOT NULL,
    committee_code  text NOT NULL,
    committee_name  text,
    chamber         text,
    PRIMARY KEY (billtype, billnumber, congress, committee_code)
);

-- Legislative subjects per bill (new, not previously captured)
CREATE TABLE bill_subjects (
    billtype    text NOT NULL,
    billnumber  text NOT NULL,
    congress    text NOT NULL,
    subject     text NOT NULL,
    PRIMARY KEY (billtype, billnumber, congress, subject)
);

-- Votes table: bill jsonb replaced with flat columns; member arrays moved to vote_members
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

-- Vote members: replaces yea/nay/present/notvoting jsonb arrays on votes
CREATE TABLE vote_members (
    voteid          text NOT NULL,
    bioguide_id     text NOT NULL,
    display_name    text,
    party           text,
    state           text,
    position        text NOT NULL,
    PRIMARY KEY (voteid, bioguide_id)
);
