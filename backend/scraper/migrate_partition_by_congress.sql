-- Migration: re-partition bills from PARTITION BY LIST (billtype)
--            to          PARTITION BY LIST (congress)
--
-- Safe to run against a live database; the whole thing is wrapped in a
-- single transaction so it is all-or-nothing.  Expect a full table-scan
-- copy of the bills table which may take several minutes on large datasets.
--
-- Usage:
--   psql "$DATABASE_URL" -f migrate_partition_by_congress.sql

BEGIN;

-- ─── 1. Sever the circular FK: bills → bill_actions ─────────────────────────
ALTER TABLE bills DROP CONSTRAINT bills_latest_action_fkey;

-- ─── 2. Drop child-table FKs pointing to bills ──────────────────────────────
ALTER TABLE bill_actions   DROP CONSTRAINT bill_actions_bill_fkey;
ALTER TABLE bill_cosponsors DROP CONSTRAINT bill_cosponsors_bill_fkey;
ALTER TABLE bill_committees DROP CONSTRAINT bill_committees_bill_fkey;
ALTER TABLE bill_subjects   DROP CONSTRAINT bill_subjects_bill_fkey;

-- ─── 2b. Align child-table key types with the new parent schema ─────────────
ALTER TABLE bill_actions
    ALTER COLUMN billnumber TYPE integer USING billnumber::integer,
    ALTER COLUMN congress TYPE integer USING congress::integer,
    ALTER COLUMN acted_at TYPE date USING acted_at::date;

ALTER TABLE bill_cosponsors
    ALTER COLUMN billnumber TYPE integer USING billnumber::integer,
    ALTER COLUMN congress TYPE integer USING congress::integer,
    ALTER COLUMN sponsorship_date TYPE date USING sponsorship_date::date;

ALTER TABLE bill_committees
    ALTER COLUMN billnumber TYPE integer USING billnumber::integer,
    ALTER COLUMN congress TYPE integer USING congress::integer;

ALTER TABLE bill_subjects
    ALTER COLUMN billnumber TYPE integer USING billnumber::integer,
    ALTER COLUMN congress TYPE integer USING congress::integer;

ALTER TABLE votes
    ALTER COLUMN bill_number TYPE integer USING bill_number::integer,
    ALTER COLUMN congress TYPE integer USING congress::integer,
    ALTER COLUMN votenumber TYPE integer USING votenumber::integer,
    ALTER COLUMN votedate TYPE date USING votedate::date;

-- ─── 2c. Normalize committee metadata into its own table ───────────────────
CREATE TABLE committees (
    committee_code text PRIMARY KEY,
    committee_name text,
    chamber        text
);

INSERT INTO committees (committee_code, committee_name, chamber)
SELECT DISTINCT ON (committee_code)
    committee_code,
    committee_name,
    chamber
FROM bill_committees
ORDER BY committee_code, committee_name NULLS LAST, chamber NULLS LAST;

CREATE INDEX committees_chamber_idx
    ON committees (chamber);

ALTER TABLE bill_committees
    DROP COLUMN committee_name,
    DROP COLUMN chamber;

-- ─── 3. Build the replacement table (non-generated columns only) ─────────────
CREATE TABLE bills_new (
    billid              text,
    billnumber          integer NOT NULL,
    billtype            text NOT NULL,
    introducedat        date,
    congress            integer NOT NULL,
    summary_date        text,
    summary_text        text,
    sponsor_bioguide_id text,
    sponsor_name        text,
    sponsor_state       text,
    sponsor_party       text,
    origin_chamber      text,
    policy_area         text,
    update_date         date,
    latest_action_id    bigint,
    latest_action_date  date,
    bill_status         text NOT NULL,
    statusat            date NOT NULL,
    shorttitle          text,
    officialtitle       text,
    CONSTRAINT bill_new_pkey PRIMARY KEY (billtype, billnumber, congress)
) PARTITION BY LIST (congress);

-- ─── 4. Congress partitions 93–119 + default ────────────────────────────────
CREATE TABLE bills_93  PARTITION OF bills_new FOR VALUES IN (93);
CREATE TABLE bills_94  PARTITION OF bills_new FOR VALUES IN (94);
CREATE TABLE bills_95  PARTITION OF bills_new FOR VALUES IN (95);
CREATE TABLE bills_96  PARTITION OF bills_new FOR VALUES IN (96);
CREATE TABLE bills_97  PARTITION OF bills_new FOR VALUES IN (97);
CREATE TABLE bills_98  PARTITION OF bills_new FOR VALUES IN (98);
CREATE TABLE bills_99  PARTITION OF bills_new FOR VALUES IN (99);
CREATE TABLE bills_100 PARTITION OF bills_new FOR VALUES IN (100);
CREATE TABLE bills_101 PARTITION OF bills_new FOR VALUES IN (101);
CREATE TABLE bills_102 PARTITION OF bills_new FOR VALUES IN (102);
CREATE TABLE bills_103 PARTITION OF bills_new FOR VALUES IN (103);
CREATE TABLE bills_104 PARTITION OF bills_new FOR VALUES IN (104);
CREATE TABLE bills_105 PARTITION OF bills_new FOR VALUES IN (105);
CREATE TABLE bills_106 PARTITION OF bills_new FOR VALUES IN (106);
CREATE TABLE bills_107 PARTITION OF bills_new FOR VALUES IN (107);
CREATE TABLE bills_108 PARTITION OF bills_new FOR VALUES IN (108);
CREATE TABLE bills_109 PARTITION OF bills_new FOR VALUES IN (109);
CREATE TABLE bills_110 PARTITION OF bills_new FOR VALUES IN (110);
CREATE TABLE bills_111 PARTITION OF bills_new FOR VALUES IN (111);
CREATE TABLE bills_112 PARTITION OF bills_new FOR VALUES IN (112);
CREATE TABLE bills_113 PARTITION OF bills_new FOR VALUES IN (113);
CREATE TABLE bills_114 PARTITION OF bills_new FOR VALUES IN (114);
CREATE TABLE bills_115 PARTITION OF bills_new FOR VALUES IN (115);
CREATE TABLE bills_116 PARTITION OF bills_new FOR VALUES IN (116);
CREATE TABLE bills_117 PARTITION OF bills_new FOR VALUES IN (117);
CREATE TABLE bills_118 PARTITION OF bills_new FOR VALUES IN (118);
CREATE TABLE bills_119 PARTITION OF bills_new FOR VALUES IN (119);
CREATE TABLE bills_default PARTITION OF bills_new DEFAULT;

-- ─── 5. Generated tsvector columns ──────────────────────────────────────────
ALTER TABLE bills_new ADD COLUMN s_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN hr_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN hconres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN hjres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN hres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN sconres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN sjres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN sres_ts tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(shorttitle, '') || ' ' || coalesce(summary_text, ''))
) STORED;
ALTER TABLE bills_new ADD COLUMN search_document tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(shorttitle, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(officialtitle, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(summary_text, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(sponsor_name, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(policy_area, '')), 'C')
) STORED;

-- ─── 6. Copy all rows (generated columns are computed automatically) ─────────
INSERT INTO bills_new (
    billid, billnumber, billtype, introducedat, congress,
    summary_date, summary_text, sponsor_bioguide_id, sponsor_name,
    sponsor_state, sponsor_party, origin_chamber, policy_area,
    update_date, latest_action_id, latest_action_date, bill_status, statusat,
    shorttitle, officialtitle
)
SELECT
    billid, billnumber, billtype, introducedat, congress,
    summary_date, summary_text, sponsor_bioguide_id, sponsor_name,
    sponsor_state, sponsor_party, origin_chamber, policy_area,
    update_date, latest_action_id, latest_action_date, bill_status, statusat,
    shorttitle, officialtitle
FROM bills;

-- ─── 7. Drop old table (cascades to its billtype partitions: bills_s, bills_hr, etc.) ──
DROP TABLE bills;

-- ─── 8. Promote the new table ────────────────────────────────────────────────
ALTER TABLE bills_new     RENAME TO bills;
ALTER TABLE bill_new_pkey RENAME TO bill_pkey;  -- rename PK constraint

-- ─── 9. Rebuild indexes ──────────────────────────────────────────────────────
CREATE INDEX s_ts_idx ON bills USING GIN (s_ts);
CREATE INDEX hr_ts_idx ON bills USING GIN (hr_ts);
CREATE INDEX hconres_ts_idx ON bills USING GIN (hconres_ts);
CREATE INDEX hjres_ts_idx ON bills USING GIN (hjres_ts);
CREATE INDEX hres_ts_idx ON bills USING GIN (hres_ts);
CREATE INDEX sconres_ts_idx ON bills USING GIN (sconres_ts);
CREATE INDEX sjres_ts_idx ON bills USING GIN (sjres_ts);
CREATE INDEX sres_ts_idx ON bills USING GIN (sres_ts);
CREATE INDEX bills_search_document_idx ON bills USING GIN (search_document);
CREATE INDEX bills_billtype_idx ON bills (billtype, congress);
CREATE INDEX bills_latest_action_date_idx
    ON bills (latest_action_date DESC NULLS LAST);
CREATE INDEX bills_statusat_update_date_idx
    ON bills (statusat DESC, update_date DESC NULLS LAST);
CREATE INDEX bills_missing_metadata_idx
    ON bills (congress, billtype, billnumber)
    WHERE shorttitle IS NULL
       OR officialtitle IS NULL
       OR sponsor_name IS NULL
       OR summary_text IS NULL
       OR policy_area IS NULL;

-- ─── 10. Recreate bill_actions unique index needed by FK ─────────────────────
-- (The unique index on bill_actions was not dropped, but verify it exists.)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'bill_actions'
          AND indexname  = 'bill_actions_id_bill_lookup_idx'
    ) THEN
        CREATE UNIQUE INDEX bill_actions_id_bill_lookup_idx
            ON bill_actions (id, billtype, billnumber, congress);
    END IF;
END$$;

-- ─── 11. Restore all foreign-key constraints ─────────────────────────────────
ALTER TABLE bill_actions
    ADD CONSTRAINT bill_actions_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE;

ALTER TABLE bill_cosponsors
    ADD CONSTRAINT bill_cosponsors_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE;

ALTER TABLE bill_committees
    ADD CONSTRAINT bill_committees_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE;

ALTER TABLE bill_committees
    ADD CONSTRAINT bill_committees_committee_fkey
        FOREIGN KEY (committee_code)
        REFERENCES committees (committee_code)
        ON DELETE CASCADE;

ALTER TABLE bill_subjects
    ADD CONSTRAINT bill_subjects_bill_fkey
        FOREIGN KEY (billtype, billnumber, congress)
        REFERENCES bills (billtype, billnumber, congress)
        ON DELETE CASCADE;

ALTER TABLE bills
    ADD CONSTRAINT bills_latest_action_fkey
        FOREIGN KEY (latest_action_id, billtype, billnumber, congress)
        REFERENCES bill_actions (id, billtype, billnumber, congress)
        ON DELETE SET NULL;

COMMIT;
