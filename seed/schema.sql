CREATE TABLE bills(
    billid  text,
    billnumber  text,
    billtype    text,
    introducedat    text,
    congress text,
    summary jsonb,
    actions jsonb,
    sponsors jsonb,
    cosponsors jsonb,
    statusat text,
    shorttitle text,
    officialtitle text,
    CONSTRAINT bill_pkey PRIMARY KEY (billtype,billnumber,congress)
) partition by list (billtype);

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

ALTER TABLE bills ADD COLUMN s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX s_ts_idx ON bills USING GIN (s_ts);

ALTER TABLE bills ADD COLUMN hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX hr_ts_idx ON bills USING GIN (hr_ts);

ALTER TABLE bills ADD COLUMN hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX hconres_ts_idx ON bills USING GIN (hconres_ts);

ALTER TABLE bills ADD COLUMN hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX hjres_ts_idx ON bills USING GIN (hjres_ts);

ALTER TABLE bills ADD COLUMN hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX hres_ts_idx ON bills USING GIN (hres_ts);


ALTER TABLE bills ADD COLUMN sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX sconres_ts_idx ON bills USING GIN (sconres_ts);

ALTER TABLE bills ADD COLUMN sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX sjres_ts_idx ON bills USING GIN (sjres_ts);

ALTER TABLE bills ADD COLUMN sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(shorttitle,'') || ' ' || coalesce(summary->>'Text',''))) STORED;
CREATE INDEX sres_ts_idx ON bills USING GIN (sres_ts);
