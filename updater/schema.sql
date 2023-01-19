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
    CONSTRAINT bill_pkey PRIMARY KEY (billtype,billnumber,congress,statusat)
) partition by range(statusat);

CREATE TABLE bills1973 PARTITION OF bills
    FOR VALUES FROM ('1973-01-01') TO ('1974-01-01');
CREATE TABLE bills1974 PARTITION OF bills
    FOR VALUES FROM ('1974-01-01') TO ('1975-01-01');
CREATE TABLE bills1975 PARTITION OF bills
    FOR VALUES FROM ('1975-01-01') TO ('1976-01-01');
CREATE TABLE bills1976 PARTITION OF bills
    FOR VALUES FROM ('1976-01-01') TO ('1977-01-01');
CREATE TABLE bills1977 PARTITION OF bills
    FOR VALUES FROM ('1977-01-01') TO ('1978-01-01');
CREATE TABLE bills1978 PARTITION OF bills
    FOR VALUES FROM ('1978-01-01') TO ('1979-01-01');
CREATE TABLE bills1979 PARTITION OF bills
    FOR VALUES FROM ('1979-01-01') TO ('1980-01-01');
CREATE TABLE bills1980 PARTITION OF bills
    FOR VALUES FROM ('1980-01-01') TO ('1981-01-01');
CREATE TABLE bills1981 PARTITION OF bills
    FOR VALUES FROM ('1981-01-01') TO ('1982-01-01');
CREATE TABLE bills1982 PARTITION OF bills
    FOR VALUES FROM ('1982-01-01') TO ('1983-01-01');
CREATE TABLE bills1983 PARTITION OF bills
    FOR VALUES FROM ('1983-01-01') TO ('1984-01-01');
CREATE TABLE bills1984 PARTITION OF bills
    FOR VALUES FROM ('1984-01-01') TO ('1985-01-01');
CREATE TABLE bills1985 PARTITION OF bills
    FOR VALUES FROM ('1985-01-01') TO ('1986-01-01');
CREATE TABLE bills1986 PARTITION OF bills
    FOR VALUES FROM ('1986-01-01') TO ('1987-01-01');
CREATE TABLE bills1987 PARTITION OF bills
    FOR VALUES FROM ('1987-01-01') TO ('1988-01-01');
CREATE TABLE bills1988 PARTITION OF bills
    FOR VALUES FROM ('1988-01-01') TO ('1989-01-01');
CREATE TABLE bills1989 PARTITION OF bills
    FOR VALUES FROM ('1989-01-01') TO ('1990-01-01');
CREATE TABLE bills1990 PARTITION OF bills
    FOR VALUES FROM ('1990-01-01') TO ('1991-01-01');
CREATE TABLE bills1991 PARTITION OF bills
    FOR VALUES FROM ('1991-01-01') TO ('1992-01-01');
CREATE TABLE bills1992 PARTITION OF bills
    FOR VALUES FROM ('1992-01-01') TO ('1993-01-01');
CREATE TABLE bills1993 PARTITION OF bills
    FOR VALUES FROM ('1993-01-01') TO ('1994-01-01');
CREATE TABLE bills1994 PARTITION OF bills
    FOR VALUES FROM ('1994-01-01') TO ('1995-01-01');
CREATE TABLE bills1995 PARTITION OF bills
    FOR VALUES FROM ('1995-01-01') TO ('1996-01-01');
CREATE TABLE bills1996 PARTITION OF bills
    FOR VALUES FROM ('1996-01-01') TO ('1997-01-01');
CREATE TABLE bills1997 PARTITION OF bills
    FOR VALUES FROM ('1997-01-01') TO ('1998-01-01');
CREATE TABLE bills1998 PARTITION OF bills
    FOR VALUES FROM ('1998-01-01') TO ('1999-01-01');
CREATE TABLE bills1999 PARTITION OF bills
    FOR VALUES FROM ('1999-01-01') TO ('2000-01-01');
CREATE TABLE bills2000 PARTITION OF bills
    FOR VALUES FROM ('2000-01-01') TO ('2001-01-01');
CREATE TABLE bills2001 PARTITION OF bills
    FOR VALUES FROM ('2001-01-01') TO ('2002-01-01');
CREATE TABLE bills2002 PARTITION OF bills
    FOR VALUES FROM ('2002-01-01') TO ('2003-01-01');
CREATE TABLE bills2003 PARTITION OF bills
    FOR VALUES FROM ('2003-01-01') TO ('2004-01-01');
CREATE TABLE bills2004 PARTITION OF bills
    FOR VALUES FROM ('2004-01-01') TO ('2005-01-01');
CREATE TABLE bills2005 PARTITION OF bills
    FOR VALUES FROM ('2005-01-01') TO ('2006-01-01');
CREATE TABLE bills2006 PARTITION OF bills
    FOR VALUES FROM ('2006-01-01') TO ('2007-01-01');
CREATE TABLE bills2007 PARTITION OF bills
    FOR VALUES FROM ('2007-01-01') TO ('2008-01-01');
CREATE TABLE bills2008 PARTITION OF bills
    FOR VALUES FROM ('2008-01-01') TO ('2009-01-01');
CREATE TABLE bills2009 PARTITION OF bills
    FOR VALUES FROM ('2009-01-01') TO ('2010-01-01');
CREATE TABLE bills2010 PARTITION OF bills
    FOR VALUES FROM ('2010-01-01') TO ('2011-01-01');
CREATE TABLE bills2011 PARTITION OF bills
    FOR VALUES FROM ('2011-01-01') TO ('2012-01-01');
CREATE TABLE bills2012 PARTITION OF bills
    FOR VALUES FROM ('2012-01-01') TO ('2013-01-01');
CREATE TABLE bills2013 PARTITION OF bills
    FOR VALUES FROM ('2013-01-01') TO ('2014-01-01');
CREATE TABLE bills2014 PARTITION OF bills
    FOR VALUES FROM ('2014-01-01') TO ('2015-01-01');
CREATE TABLE bills2015 PARTITION OF bills
    FOR VALUES FROM ('2015-01-01') TO ('2016-01-01');
CREATE TABLE bills2016 PARTITION OF bills
    FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');
CREATE TABLE bills2017 PARTITION OF bills
    FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');
CREATE TABLE bills2018 PARTITION OF bills
    FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');
CREATE TABLE bills2019 PARTITION OF bills
    FOR VALUES FROM ('2019-01-01') TO ('2020-01-01');
CREATE TABLE bills2020 PARTITION OF bills
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE bills2021 PARTITION OF bills
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE bills2022 PARTITION OF bills
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE bills2023 PARTITION OF bills
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE bills2024 PARTITION OF bills
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE bills2025 PARTITION OF bills
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE bills2026 PARTITION OF bills
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE bills2027 PARTITION OF bills
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE bills2028 PARTITION OF bills
    FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
CREATE INDEX ON bills (statusat);
CREATE INDEX ON bills1973(billtype);
CREATE INDEX ON bills1974(billtype);
CREATE INDEX ON bills1975(billtype);
CREATE INDEX ON bills1976(billtype);
CREATE INDEX ON bills1977(billtype);
CREATE INDEX ON bills1978(billtype);
CREATE INDEX ON bills1979(billtype);
CREATE INDEX ON bills1980(billtype);
CREATE INDEX ON bills1981(billtype);
CREATE INDEX ON bills1982(billtype);
CREATE INDEX ON bills1983(billtype);
CREATE INDEX ON bills1984(billtype);
CREATE INDEX ON bills1985(billtype);
CREATE INDEX ON bills1986(billtype);
CREATE INDEX ON bills1987(billtype);
CREATE INDEX ON bills1988(billtype);
CREATE INDEX ON bills1989(billtype);
CREATE INDEX ON bills1990(billtype);
CREATE INDEX ON bills1991(billtype);
CREATE INDEX ON bills1992(billtype);
CREATE INDEX ON bills1993(billtype);
CREATE INDEX ON bills1994(billtype);
CREATE INDEX ON bills1995(billtype);
CREATE INDEX ON bills1996(billtype);
CREATE INDEX ON bills1997(billtype);
CREATE INDEX ON bills1998(billtype);
CREATE INDEX ON bills1999(billtype);
CREATE INDEX ON bills2000(billtype);
CREATE INDEX ON bills2001(billtype);
CREATE INDEX ON bills2002(billtype);
CREATE INDEX ON bills2003(billtype);
CREATE INDEX ON bills2004(billtype);
CREATE INDEX ON bills2005(billtype);
CREATE INDEX ON bills2006(billtype);
CREATE INDEX ON bills2007(billtype);
CREATE INDEX ON bills2008(billtype);
CREATE INDEX ON bills2009(billtype);
CREATE INDEX ON bills2010(billtype);
CREATE INDEX ON bills2011(billtype);
CREATE INDEX ON bills2012(billtype);
CREATE INDEX ON bills2013(billtype);
CREATE INDEX ON bills2014(billtype);
CREATE INDEX ON bills2015(billtype);
CREATE INDEX ON bills2016(billtype);
CREATE INDEX ON bills2017(billtype);
CREATE INDEX ON bills2018(billtype);
CREATE INDEX ON bills2019(billtype);
CREATE INDEX ON bills2020(billtype);
CREATE INDEX ON bills2021(billtype);
CREATE INDEX ON bills2022(billtype);
CREATE INDEX ON bills2023(billtype);
CREATE INDEX ON bills2024(billtype);
CREATE INDEX ON bills2025(billtype);
CREATE INDEX ON bills2026(billtype);
CREATE INDEX ON bills2027(billtype);
CREATE INDEX ON bills2028(billtype);



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
