--
-- PostgreSQL database dump
--

-- Dumped from database version 15.1 (Debian 15.1-1.pgdg110+1)
-- Dumped by pg_dump version 15.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

--
-- Name: bills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills (
    billid text,
    billnumber text NOT NULL,
    billtype text NOT NULL,
    introducedat text,
    congress text NOT NULL,
    summary jsonb,
    actions jsonb,
    sponsors jsonb,
    cosponsors jsonb,
    statusat text NOT NULL,
    shorttitle text,
    officialtitle text,
    votes jsonb,
    CONSTRAINT pkey_bills PRIMARY KEY (billid, statusat),
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
)
PARTITION BY RANGE (statusat);
CREATE INDEX s_ts_idx ON public.bills USING GIN (s_ts);
CREATE INDEX sconres_ts_idx ON public.bills USING GIN (sconres_ts);
CREATE INDEX sjres ON public.bills USING GIN (sjres_ts);
CREATE INDEX sres ON public.bills USING GIN (sres_ts);
CREATE INDEX hr ON public.bills USING GIN (hr_ts);
CREATE INDEX hconres_ts_idx ON public.bills USING GIN (hconres_ts);
CREATE INDEX hjres ON public.bills USING GIN (hjres_ts);
CREATE INDEX hres ON public.bills USING GIN (hres_ts);
ALTER TABLE public.bills OWNER TO postgres;

CREATE TABLE public.bills1973 PARTITION OF public.bills
    FOR VALUES FROM ('1973-01-01') TO ('1973-12-31');
CREATE TABLE public.bills1974 PARTITION OF public.bills
    FOR VALUES FROM ('1974-01-01') TO ('1974-12-31');
CREATE TABLE public.bills1975 PARTITION OF public.bills
    FOR VALUES FROM ('1975-01-01') TO ('1975-12-31');
CREATE TABLE public.bills1976 PARTITION OF public.bills
    FOR VALUES FROM ('1976-01-01') TO ('1976-12-31');
CREATE TABLE public.bills1977 PARTITION OF public.bills
    FOR VALUES FROM ('1977-01-01') TO ('1977-12-31');
CREATE TABLE public.bills1978 PARTITION OF public.bills
    FOR VALUES FROM ('1978-01-01') TO ('1978-12-31');
CREATE TABLE public.bills1979 PARTITION OF public.bills
    FOR VALUES FROM ('1979-01-01') TO ('1979-12-31');
CREATE TABLE public.bills1980 PARTITION OF public.bills
    FOR VALUES FROM ('1980-01-01') TO ('1980-12-31');
CREATE TABLE public.bills1981 PARTITION OF public.bills
    FOR VALUES FROM ('1981-01-01') TO ('1981-12-31');
CREATE TABLE public.bills1982 PARTITION OF public.bills
    FOR VALUES FROM ('1982-01-01') TO ('1982-12-31');
CREATE TABLE public.bills1983 PARTITION OF public.bills
    FOR VALUES FROM ('1983-01-01') TO ('1983-12-31');
CREATE TABLE public.bills1984 PARTITION OF public.bills
    FOR VALUES FROM ('1984-01-01') TO ('1984-12-31');
CREATE TABLE public.bills1985 PARTITION OF public.bills
    FOR VALUES FROM ('1985-01-01') TO ('1985-12-31');
CREATE TABLE public.bills1986 PARTITION OF public.bills
    FOR VALUES FROM ('1986-01-01') TO ('1986-12-31');
CREATE TABLE public.bills1987 PARTITION OF public.bills
    FOR VALUES FROM ('1987-01-01') TO ('1987-12-31');
CREATE TABLE public.bills1988 PARTITION OF public.bills
    FOR VALUES FROM ('1988-01-01') TO ('1988-12-31');
CREATE TABLE public.bills1989 PARTITION OF public.bills
    FOR VALUES FROM ('1989-01-01') TO ('1989-12-31');
CREATE TABLE public.bills1990 PARTITION OF public.bills
    FOR VALUES FROM ('1990-01-01') TO ('1990-12-31');
CREATE TABLE public.bills1991 PARTITION OF public.bills
    FOR VALUES FROM ('1991-01-01') TO ('1991-12-31');
CREATE TABLE public.bills1992 PARTITION OF public.bills
    FOR VALUES FROM ('1992-01-01') TO ('1992-12-31');
CREATE TABLE public.bills1993 PARTITION OF public.bills
    FOR VALUES FROM ('1993-01-01') TO ('1993-12-31');
CREATE TABLE public.bills1994 PARTITION OF public.bills
    FOR VALUES FROM ('1994-01-01') TO ('1994-12-31');
CREATE TABLE public.bills1995 PARTITION OF public.bills
    FOR VALUES FROM ('1995-01-01') TO ('1995-12-31');
CREATE TABLE public.bills1996 PARTITION OF public.bills
    FOR VALUES FROM ('1996-01-01') TO ('1996-12-31');
CREATE TABLE public.bills1997 PARTITION OF public.bills
    FOR VALUES FROM ('1997-01-01') TO ('1997-12-31');
CREATE TABLE public.bills1998 PARTITION OF public.bills
    FOR VALUES FROM ('1998-01-01') TO ('1998-12-31');
CREATE TABLE public.bills1999 PARTITION OF public.bills
    FOR VALUES FROM ('1999-01-01') TO ('1999-12-31');
CREATE TABLE public.bills2000 PARTITION OF public.bills
    FOR VALUES FROM ('2000-01-01') TO ('2000-12-31');
CREATE TABLE public.bills2001 PARTITION OF public.bills
    FOR VALUES FROM ('2001-01-01') TO ('2001-12-31');
CREATE TABLE public.bills2002 PARTITION OF public.bills
    FOR VALUES FROM ('2002-01-01') TO ('2002-12-31');
CREATE TABLE public.bills2003 PARTITION OF public.bills
    FOR VALUES FROM ('2003-01-01') TO ('2003-12-31');
CREATE TABLE public.bills2004 PARTITION OF public.bills
    FOR VALUES FROM ('2004-01-01') TO ('2004-12-31');
CREATE TABLE public.bills2005 PARTITION OF public.bills
    FOR VALUES FROM ('2005-01-01') TO ('2005-12-31');
CREATE TABLE public.bills2006 PARTITION OF public.bills
    FOR VALUES FROM ('2006-01-01') TO ('2006-12-31');
CREATE TABLE public.bills2007 PARTITION OF public.bills
    FOR VALUES FROM ('2007-01-01') TO ('2007-12-31');
CREATE TABLE public.bills2008 PARTITION OF public.bills
    FOR VALUES FROM ('2008-01-01') TO ('2008-12-31');
CREATE TABLE public.bills2009 PARTITION OF public.bills
    FOR VALUES FROM ('2009-01-01') TO ('2009-12-31');
CREATE TABLE public.bills2010 PARTITION OF public.bills
    FOR VALUES FROM ('2010-01-01') TO ('2010-12-31');
CREATE TABLE public.bills2011 PARTITION OF public.bills
    FOR VALUES FROM ('2011-01-01') TO ('2011-12-31');
CREATE TABLE public.bills2012 PARTITION OF public.bills
    FOR VALUES FROM ('2012-01-01') TO ('2012-12-31');
CREATE TABLE public.bills2013 PARTITION OF public.bills
    FOR VALUES FROM ('2013-01-01') TO ('2013-12-31');
CREATE TABLE public.bills2014 PARTITION OF public.bills
    FOR VALUES FROM ('2014-01-01') TO ('2014-12-31');
CREATE TABLE public.bills2015 PARTITION OF public.bills
    FOR VALUES FROM ('2015-01-01') TO ('2015-12-31');
CREATE TABLE public.bills2016 PARTITION OF public.bills
    FOR VALUES FROM ('2016-01-01') TO ('2016-12-31');
CREATE TABLE public.bills2017 PARTITION OF public.bills
    FOR VALUES FROM ('2017-01-01') TO ('2017-12-31');
CREATE TABLE public.bills2018 PARTITION OF public.bills
    FOR VALUES FROM ('2018-01-01') TO ('2018-12-31');
CREATE TABLE public.bills2019 PARTITION OF public.bills
    FOR VALUES FROM ('2019-01-01') TO ('2019-12-31');
CREATE TABLE public.bills2020 PARTITION OF public.bills
    FOR VALUES FROM ('2020-01-01') TO ('2020-12-31');
CREATE TABLE public.bills2021 PARTITION OF public.bills
    FOR VALUES FROM ('2021-01-01') TO ('2021-12-31');
CREATE TABLE public.bills2022 PARTITION OF public.bills
    FOR VALUES FROM ('2022-01-01') TO ('2022-12-31');
CREATE TABLE public.bills2023 PARTITION OF public.bills
    FOR VALUES FROM ('2023-01-01') TO ('2023-12-31');
CREATE TABLE public.bills2024 PARTITION OF public.bills
    FOR VALUES FROM ('2024-01-01') TO ('2024-12-31');
SET default_table_access_method = heap;

--
-- Name: bills2024; Type: TABLE; Schema: public; Owner: postgres
--



CREATE TABLE public.votes(
    bill jsonb,
    congress text,
    votenumber text,
    votedate text,
    question text,
    result text,
    votesession text,
    yea jsonb,
    nay jsonb,
    present jsonb,
    notvoting jsonb,
    chamber text,
    source_url text,
    votetype text,
    voteid text PRIMARY KEY
);

CREATE INDEX on public.votes (votedate);
CREATE INDEX on public.votes (voteid);
CREATE INDEX on public.votes (chamber);
CREATE INDEX on public.votes (congress);

CREATE TABLE public.users (email text, firstname text, lastname text);