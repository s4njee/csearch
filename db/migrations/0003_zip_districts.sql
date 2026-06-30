-- 0003 — ZIP code to Congressional District lookup table (structure only).
--
-- Source data: https://github.com/OpenSourceActivismTech/us-zipcodes-congress
-- (2020 Census ZCTAs, 119th Congress boundaries). The ~40k-row data load is a
-- seed, not schema, and lives in k8s/netcup-db/003-zip-districts.sql; this
-- migration only owns the table shape so the column contract is versioned.

BEGIN;

CREATE TABLE IF NOT EXISTS zip_districts (
    zcta       text NOT NULL,
    state_fips text NOT NULL,
    state_abbr text NOT NULL,
    cd         smallint NOT NULL,
    CONSTRAINT zip_districts_pkey PRIMARY KEY (zcta, state_abbr, cd)
);

CREATE INDEX IF NOT EXISTS zip_districts_zcta_idx ON zip_districts (zcta);
CREATE INDEX IF NOT EXISTS zip_districts_state_cd_idx ON zip_districts (state_abbr, cd);

COMMIT;
