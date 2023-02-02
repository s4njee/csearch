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


ALTER TABLE public.bills OWNER TO postgres;

SET default_table_access_method = heap;

--
-- Name: bills1973; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1973 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1973 OWNER TO postgres;

--
-- Name: bills1974; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1974 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1974 OWNER TO postgres;

--
-- Name: bills1975; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1975 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1975 OWNER TO postgres;

--
-- Name: bills1976; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1976 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1976 OWNER TO postgres;

--
-- Name: bills1977; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1977 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1977 OWNER TO postgres;

--
-- Name: bills1978; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1978 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1978 OWNER TO postgres;

--
-- Name: bills1979; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1979 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1979 OWNER TO postgres;

--
-- Name: bills1980; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1980 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1980 OWNER TO postgres;

--
-- Name: bills1981; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1981 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1981 OWNER TO postgres;

--
-- Name: bills1982; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1982 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1982 OWNER TO postgres;

--
-- Name: bills1983; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1983 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1983 OWNER TO postgres;

--
-- Name: bills1984; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1984 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1984 OWNER TO postgres;

--
-- Name: bills1985; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1985 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1985 OWNER TO postgres;

--
-- Name: bills1986; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1986 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1986 OWNER TO postgres;

--
-- Name: bills1987; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1987 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1987 OWNER TO postgres;

--
-- Name: bills1988; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1988 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1988 OWNER TO postgres;

--
-- Name: bills1989; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1989 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1989 OWNER TO postgres;

--
-- Name: bills1990; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1990 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1990 OWNER TO postgres;

--
-- Name: bills1991; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1991 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1991 OWNER TO postgres;

--
-- Name: bills1992; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1992 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1992 OWNER TO postgres;

--
-- Name: bills1993; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1993 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1993 OWNER TO postgres;

--
-- Name: bills1994; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1994 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1994 OWNER TO postgres;

--
-- Name: bills1995; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1995 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1995 OWNER TO postgres;

--
-- Name: bills1996; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1996 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1996 OWNER TO postgres;

--
-- Name: bills1997; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1997 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1997 OWNER TO postgres;

--
-- Name: bills1998; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1998 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1998 OWNER TO postgres;

--
-- Name: bills1999; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills1999 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills1999 OWNER TO postgres;

--
-- Name: bills2000; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2000 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2000 OWNER TO postgres;

--
-- Name: bills2001; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2001 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2001 OWNER TO postgres;

--
-- Name: bills2002; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2002 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2002 OWNER TO postgres;

--
-- Name: bills2003; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2003 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2003 OWNER TO postgres;

--
-- Name: bills2004; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2004 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2004 OWNER TO postgres;

--
-- Name: bills2005; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2005 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2005 OWNER TO postgres;

--
-- Name: bills2006; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2006 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2006 OWNER TO postgres;

--
-- Name: bills2007; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2007 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2007 OWNER TO postgres;

--
-- Name: bills2008; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2008 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2008 OWNER TO postgres;

--
-- Name: bills2009; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2009 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2009 OWNER TO postgres;

--
-- Name: bills2010; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2010 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2010 OWNER TO postgres;

--
-- Name: bills2011; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2011 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2011 OWNER TO postgres;

--
-- Name: bills2012; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2012 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2012 OWNER TO postgres;

--
-- Name: bills2013; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2013 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2013 OWNER TO postgres;

--
-- Name: bills2014; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2014 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2014 OWNER TO postgres;

--
-- Name: bills2015; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2015 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2015 OWNER TO postgres;

--
-- Name: bills2016; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2016 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2016 OWNER TO postgres;

--
-- Name: bills2017; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2017 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2017 OWNER TO postgres;

--
-- Name: bills2018; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2018 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2018 OWNER TO postgres;

--
-- Name: bills2019; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2019 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2019 OWNER TO postgres;

--
-- Name: bills2020; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2020 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2020 OWNER TO postgres;

--
-- Name: bills2021; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2021 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2021 OWNER TO postgres;

--
-- Name: bills2022; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2022 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2022 OWNER TO postgres;

--
-- Name: bills2023; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2023 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2023 OWNER TO postgres;

--
-- Name: bills2024; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2024 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2024 OWNER TO postgres;

--
-- Name: bills2025; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2025 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2025 OWNER TO postgres;

--
-- Name: bills2026; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2026 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2026 OWNER TO postgres;

--
-- Name: bills2027; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2027 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2027 OWNER TO postgres;

--
-- Name: bills2028; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills2028 (
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
    s_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hr_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    hres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sconres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sjres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED,
    sres_ts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE(shorttitle, ''::text) || ' '::text) || COALESCE((summary ->> 'Text'::text), ''::text)))) STORED
);


ALTER TABLE public.bills2028 OWNER TO postgres;

--
-- Name: bills1973; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1973 FOR VALUES FROM ('1973-01-01') TO ('1974-01-01');


--
-- Name: bills1974; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1974 FOR VALUES FROM ('1974-01-01') TO ('1975-01-01');


--
-- Name: bills1975; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1975 FOR VALUES FROM ('1975-01-01') TO ('1976-01-01');


--
-- Name: bills1976; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1976 FOR VALUES FROM ('1976-01-01') TO ('1977-01-01');


--
-- Name: bills1977; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1977 FOR VALUES FROM ('1977-01-01') TO ('1978-01-01');


--
-- Name: bills1978; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1978 FOR VALUES FROM ('1978-01-01') TO ('1979-01-01');


--
-- Name: bills1979; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1979 FOR VALUES FROM ('1979-01-01') TO ('1980-01-01');


--
-- Name: bills1980; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1980 FOR VALUES FROM ('1980-01-01') TO ('1981-01-01');


--
-- Name: bills1981; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1981 FOR VALUES FROM ('1981-01-01') TO ('1982-01-01');


--
-- Name: bills1982; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1982 FOR VALUES FROM ('1982-01-01') TO ('1983-01-01');


--
-- Name: bills1983; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1983 FOR VALUES FROM ('1983-01-01') TO ('1984-01-01');


--
-- Name: bills1984; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1984 FOR VALUES FROM ('1984-01-01') TO ('1985-01-01');


--
-- Name: bills1985; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1985 FOR VALUES FROM ('1985-01-01') TO ('1986-01-01');


--
-- Name: bills1986; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1986 FOR VALUES FROM ('1986-01-01') TO ('1987-01-01');


--
-- Name: bills1987; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1987 FOR VALUES FROM ('1987-01-01') TO ('1988-01-01');


--
-- Name: bills1988; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1988 FOR VALUES FROM ('1988-01-01') TO ('1989-01-01');


--
-- Name: bills1989; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1989 FOR VALUES FROM ('1989-01-01') TO ('1990-01-01');


--
-- Name: bills1990; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1990 FOR VALUES FROM ('1990-01-01') TO ('1991-01-01');


--
-- Name: bills1991; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1991 FOR VALUES FROM ('1991-01-01') TO ('1992-01-01');


--
-- Name: bills1992; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1992 FOR VALUES FROM ('1992-01-01') TO ('1993-01-01');


--
-- Name: bills1993; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1993 FOR VALUES FROM ('1993-01-01') TO ('1994-01-01');


--
-- Name: bills1994; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1994 FOR VALUES FROM ('1994-01-01') TO ('1995-01-01');


--
-- Name: bills1995; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1995 FOR VALUES FROM ('1995-01-01') TO ('1996-01-01');


--
-- Name: bills1996; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1996 FOR VALUES FROM ('1996-01-01') TO ('1997-01-01');


--
-- Name: bills1997; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1997 FOR VALUES FROM ('1997-01-01') TO ('1998-01-01');


--
-- Name: bills1998; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1998 FOR VALUES FROM ('1998-01-01') TO ('1999-01-01');


--
-- Name: bills1999; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills1999 FOR VALUES FROM ('1999-01-01') TO ('2000-01-01');


--
-- Name: bills2000; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2000 FOR VALUES FROM ('2000-01-01') TO ('2001-01-01');


--
-- Name: bills2001; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2001 FOR VALUES FROM ('2001-01-01') TO ('2002-01-01');


--
-- Name: bills2002; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2002 FOR VALUES FROM ('2002-01-01') TO ('2003-01-01');


--
-- Name: bills2003; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2003 FOR VALUES FROM ('2003-01-01') TO ('2004-01-01');


--
-- Name: bills2004; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2004 FOR VALUES FROM ('2004-01-01') TO ('2005-01-01');


--
-- Name: bills2005; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2005 FOR VALUES FROM ('2005-01-01') TO ('2006-01-01');


--
-- Name: bills2006; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2006 FOR VALUES FROM ('2006-01-01') TO ('2007-01-01');


--
-- Name: bills2007; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2007 FOR VALUES FROM ('2007-01-01') TO ('2008-01-01');


--
-- Name: bills2008; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2008 FOR VALUES FROM ('2008-01-01') TO ('2009-01-01');


--
-- Name: bills2009; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2009 FOR VALUES FROM ('2009-01-01') TO ('2010-01-01');


--
-- Name: bills2010; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2010 FOR VALUES FROM ('2010-01-01') TO ('2011-01-01');


--
-- Name: bills2011; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2011 FOR VALUES FROM ('2011-01-01') TO ('2012-01-01');


--
-- Name: bills2012; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2012 FOR VALUES FROM ('2012-01-01') TO ('2013-01-01');


--
-- Name: bills2013; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2013 FOR VALUES FROM ('2013-01-01') TO ('2014-01-01');


--
-- Name: bills2014; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2014 FOR VALUES FROM ('2014-01-01') TO ('2015-01-01');


--
-- Name: bills2015; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2015 FOR VALUES FROM ('2015-01-01') TO ('2016-01-01');


--
-- Name: bills2016; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2016 FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');


--
-- Name: bills2017; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2017 FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');


--
-- Name: bills2018; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2018 FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');


--
-- Name: bills2019; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2019 FOR VALUES FROM ('2019-01-01') TO ('2020-01-01');


--
-- Name: bills2020; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2020 FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');


--
-- Name: bills2021; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2021 FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');


--
-- Name: bills2022; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2022 FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');


--
-- Name: bills2023; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2023 FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');


--
-- Name: bills2024; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2024 FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');


--
-- Name: bills2025; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2025 FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');


--
-- Name: bills2026; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2026 FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');


--
-- Name: bills2027; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2027 FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');


--
-- Name: bills2028; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ATTACH PARTITION public.bills2028 FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');


--
-- Name: bills bill_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bill_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1973 bills1973_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1973
    ADD CONSTRAINT bills1973_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1974 bills1974_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1974
    ADD CONSTRAINT bills1974_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1975 bills1975_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1975
    ADD CONSTRAINT bills1975_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1976 bills1976_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1976
    ADD CONSTRAINT bills1976_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1977 bills1977_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1977
    ADD CONSTRAINT bills1977_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1978 bills1978_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1978
    ADD CONSTRAINT bills1978_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1979 bills1979_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1979
    ADD CONSTRAINT bills1979_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1980 bills1980_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1980
    ADD CONSTRAINT bills1980_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1981 bills1981_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1981
    ADD CONSTRAINT bills1981_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1982 bills1982_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1982
    ADD CONSTRAINT bills1982_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1983 bills1983_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1983
    ADD CONSTRAINT bills1983_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1984 bills1984_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1984
    ADD CONSTRAINT bills1984_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1985 bills1985_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1985
    ADD CONSTRAINT bills1985_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1986 bills1986_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1986
    ADD CONSTRAINT bills1986_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1987 bills1987_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1987
    ADD CONSTRAINT bills1987_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1988 bills1988_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1988
    ADD CONSTRAINT bills1988_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1989 bills1989_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1989
    ADD CONSTRAINT bills1989_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1990 bills1990_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1990
    ADD CONSTRAINT bills1990_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1991 bills1991_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1991
    ADD CONSTRAINT bills1991_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1992 bills1992_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1992
    ADD CONSTRAINT bills1992_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1993 bills1993_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1993
    ADD CONSTRAINT bills1993_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1994 bills1994_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1994
    ADD CONSTRAINT bills1994_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1995 bills1995_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1995
    ADD CONSTRAINT bills1995_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1996 bills1996_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1996
    ADD CONSTRAINT bills1996_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1997 bills1997_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1997
    ADD CONSTRAINT bills1997_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1998 bills1998_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1998
    ADD CONSTRAINT bills1998_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills1999 bills1999_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills1999
    ADD CONSTRAINT bills1999_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2000 bills2000_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2000
    ADD CONSTRAINT bills2000_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2001 bills2001_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2001
    ADD CONSTRAINT bills2001_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2002 bills2002_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2002
    ADD CONSTRAINT bills2002_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2003 bills2003_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2003
    ADD CONSTRAINT bills2003_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2004 bills2004_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2004
    ADD CONSTRAINT bills2004_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2005 bills2005_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2005
    ADD CONSTRAINT bills2005_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2006 bills2006_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2006
    ADD CONSTRAINT bills2006_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2007 bills2007_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2007
    ADD CONSTRAINT bills2007_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2008 bills2008_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2008
    ADD CONSTRAINT bills2008_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2009 bills2009_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2009
    ADD CONSTRAINT bills2009_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2010 bills2010_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2010
    ADD CONSTRAINT bills2010_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2011 bills2011_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2011
    ADD CONSTRAINT bills2011_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2012 bills2012_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2012
    ADD CONSTRAINT bills2012_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2013 bills2013_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2013
    ADD CONSTRAINT bills2013_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2014 bills2014_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2014
    ADD CONSTRAINT bills2014_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2015 bills2015_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2015
    ADD CONSTRAINT bills2015_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2016 bills2016_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2016
    ADD CONSTRAINT bills2016_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2017 bills2017_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2017
    ADD CONSTRAINT bills2017_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2018 bills2018_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2018
    ADD CONSTRAINT bills2018_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2019 bills2019_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2019
    ADD CONSTRAINT bills2019_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2020 bills2020_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2020
    ADD CONSTRAINT bills2020_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2021 bills2021_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2021
    ADD CONSTRAINT bills2021_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2022 bills2022_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2022
    ADD CONSTRAINT bills2022_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2023 bills2023_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2023
    ADD CONSTRAINT bills2023_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2024 bills2024_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2024
    ADD CONSTRAINT bills2024_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2025 bills2025_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2025
    ADD CONSTRAINT bills2025_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2026 bills2026_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2026
    ADD CONSTRAINT bills2026_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2027 bills2027_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2027
    ADD CONSTRAINT bills2027_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills2028 bills2028_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills2028
    ADD CONSTRAINT bills2028_pkey PRIMARY KEY (billtype, billnumber, congress, statusat);


--
-- Name: bills_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills_billtype_idx ON ONLY public.bills USING btree (billtype);


--
-- Name: bills1973_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_billtype_idx ON public.bills1973 USING btree (billtype);


--
-- Name: hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX hconres_ts_idx ON ONLY public.bills USING gin (hconres_ts);


--
-- Name: bills1973_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_hconres_ts_idx ON public.bills1973 USING gin (hconres_ts);


--
-- Name: hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX hjres_ts_idx ON ONLY public.bills USING gin (hjres_ts);


--
-- Name: bills1973_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_hjres_ts_idx ON public.bills1973 USING gin (hjres_ts);


--
-- Name: hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX hr_ts_idx ON ONLY public.bills USING gin (hr_ts);


--
-- Name: bills1973_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_hr_ts_idx ON public.bills1973 USING gin (hr_ts);


--
-- Name: hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX hres_ts_idx ON ONLY public.bills USING gin (hres_ts);


--
-- Name: bills1973_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_hres_ts_idx ON public.bills1973 USING gin (hres_ts);


--
-- Name: s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX s_ts_idx ON ONLY public.bills USING gin (s_ts);


--
-- Name: bills1973_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_s_ts_idx ON public.bills1973 USING gin (s_ts);


--
-- Name: sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sconres_ts_idx ON ONLY public.bills USING gin (sconres_ts);


--
-- Name: bills1973_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_sconres_ts_idx ON public.bills1973 USING gin (sconres_ts);


--
-- Name: sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sjres_ts_idx ON ONLY public.bills USING gin (sjres_ts);


--
-- Name: bills1973_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_sjres_ts_idx ON public.bills1973 USING gin (sjres_ts);


--
-- Name: sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sres_ts_idx ON ONLY public.bills USING gin (sres_ts);


--
-- Name: bills1973_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_sres_ts_idx ON public.bills1973 USING gin (sres_ts);


--
-- Name: bills_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills_statusat_idx ON ONLY public.bills USING btree (statusat);


--
-- Name: bills1973_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1973_statusat_idx ON public.bills1973 USING btree (statusat);


--
-- Name: bills1974_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_billtype_idx ON public.bills1974 USING btree (billtype);


--
-- Name: bills1974_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_hconres_ts_idx ON public.bills1974 USING gin (hconres_ts);


--
-- Name: bills1974_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_hjres_ts_idx ON public.bills1974 USING gin (hjres_ts);


--
-- Name: bills1974_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_hr_ts_idx ON public.bills1974 USING gin (hr_ts);


--
-- Name: bills1974_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_hres_ts_idx ON public.bills1974 USING gin (hres_ts);


--
-- Name: bills1974_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_s_ts_idx ON public.bills1974 USING gin (s_ts);


--
-- Name: bills1974_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_sconres_ts_idx ON public.bills1974 USING gin (sconres_ts);


--
-- Name: bills1974_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_sjres_ts_idx ON public.bills1974 USING gin (sjres_ts);


--
-- Name: bills1974_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_sres_ts_idx ON public.bills1974 USING gin (sres_ts);


--
-- Name: bills1974_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1974_statusat_idx ON public.bills1974 USING btree (statusat);


--
-- Name: bills1975_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_billtype_idx ON public.bills1975 USING btree (billtype);


--
-- Name: bills1975_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_hconres_ts_idx ON public.bills1975 USING gin (hconres_ts);


--
-- Name: bills1975_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_hjres_ts_idx ON public.bills1975 USING gin (hjres_ts);


--
-- Name: bills1975_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_hr_ts_idx ON public.bills1975 USING gin (hr_ts);


--
-- Name: bills1975_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_hres_ts_idx ON public.bills1975 USING gin (hres_ts);


--
-- Name: bills1975_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_s_ts_idx ON public.bills1975 USING gin (s_ts);


--
-- Name: bills1975_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_sconres_ts_idx ON public.bills1975 USING gin (sconres_ts);


--
-- Name: bills1975_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_sjres_ts_idx ON public.bills1975 USING gin (sjres_ts);


--
-- Name: bills1975_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_sres_ts_idx ON public.bills1975 USING gin (sres_ts);


--
-- Name: bills1975_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1975_statusat_idx ON public.bills1975 USING btree (statusat);


--
-- Name: bills1976_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_billtype_idx ON public.bills1976 USING btree (billtype);


--
-- Name: bills1976_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_hconres_ts_idx ON public.bills1976 USING gin (hconres_ts);


--
-- Name: bills1976_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_hjres_ts_idx ON public.bills1976 USING gin (hjres_ts);


--
-- Name: bills1976_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_hr_ts_idx ON public.bills1976 USING gin (hr_ts);


--
-- Name: bills1976_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_hres_ts_idx ON public.bills1976 USING gin (hres_ts);


--
-- Name: bills1976_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_s_ts_idx ON public.bills1976 USING gin (s_ts);


--
-- Name: bills1976_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_sconres_ts_idx ON public.bills1976 USING gin (sconres_ts);


--
-- Name: bills1976_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_sjres_ts_idx ON public.bills1976 USING gin (sjres_ts);


--
-- Name: bills1976_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_sres_ts_idx ON public.bills1976 USING gin (sres_ts);


--
-- Name: bills1976_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1976_statusat_idx ON public.bills1976 USING btree (statusat);


--
-- Name: bills1977_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_billtype_idx ON public.bills1977 USING btree (billtype);


--
-- Name: bills1977_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_hconres_ts_idx ON public.bills1977 USING gin (hconres_ts);


--
-- Name: bills1977_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_hjres_ts_idx ON public.bills1977 USING gin (hjres_ts);


--
-- Name: bills1977_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_hr_ts_idx ON public.bills1977 USING gin (hr_ts);


--
-- Name: bills1977_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_hres_ts_idx ON public.bills1977 USING gin (hres_ts);


--
-- Name: bills1977_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_s_ts_idx ON public.bills1977 USING gin (s_ts);


--
-- Name: bills1977_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_sconres_ts_idx ON public.bills1977 USING gin (sconres_ts);


--
-- Name: bills1977_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_sjres_ts_idx ON public.bills1977 USING gin (sjres_ts);


--
-- Name: bills1977_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_sres_ts_idx ON public.bills1977 USING gin (sres_ts);


--
-- Name: bills1977_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1977_statusat_idx ON public.bills1977 USING btree (statusat);


--
-- Name: bills1978_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_billtype_idx ON public.bills1978 USING btree (billtype);


--
-- Name: bills1978_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_hconres_ts_idx ON public.bills1978 USING gin (hconres_ts);


--
-- Name: bills1978_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_hjres_ts_idx ON public.bills1978 USING gin (hjres_ts);


--
-- Name: bills1978_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_hr_ts_idx ON public.bills1978 USING gin (hr_ts);


--
-- Name: bills1978_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_hres_ts_idx ON public.bills1978 USING gin (hres_ts);


--
-- Name: bills1978_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_s_ts_idx ON public.bills1978 USING gin (s_ts);


--
-- Name: bills1978_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_sconres_ts_idx ON public.bills1978 USING gin (sconres_ts);


--
-- Name: bills1978_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_sjres_ts_idx ON public.bills1978 USING gin (sjres_ts);


--
-- Name: bills1978_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_sres_ts_idx ON public.bills1978 USING gin (sres_ts);


--
-- Name: bills1978_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1978_statusat_idx ON public.bills1978 USING btree (statusat);


--
-- Name: bills1979_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_billtype_idx ON public.bills1979 USING btree (billtype);


--
-- Name: bills1979_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_hconres_ts_idx ON public.bills1979 USING gin (hconres_ts);


--
-- Name: bills1979_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_hjres_ts_idx ON public.bills1979 USING gin (hjres_ts);


--
-- Name: bills1979_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_hr_ts_idx ON public.bills1979 USING gin (hr_ts);


--
-- Name: bills1979_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_hres_ts_idx ON public.bills1979 USING gin (hres_ts);


--
-- Name: bills1979_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_s_ts_idx ON public.bills1979 USING gin (s_ts);


--
-- Name: bills1979_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_sconres_ts_idx ON public.bills1979 USING gin (sconres_ts);


--
-- Name: bills1979_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_sjres_ts_idx ON public.bills1979 USING gin (sjres_ts);


--
-- Name: bills1979_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_sres_ts_idx ON public.bills1979 USING gin (sres_ts);


--
-- Name: bills1979_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1979_statusat_idx ON public.bills1979 USING btree (statusat);


--
-- Name: bills1980_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_billtype_idx ON public.bills1980 USING btree (billtype);


--
-- Name: bills1980_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_hconres_ts_idx ON public.bills1980 USING gin (hconres_ts);


--
-- Name: bills1980_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_hjres_ts_idx ON public.bills1980 USING gin (hjres_ts);


--
-- Name: bills1980_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_hr_ts_idx ON public.bills1980 USING gin (hr_ts);


--
-- Name: bills1980_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_hres_ts_idx ON public.bills1980 USING gin (hres_ts);


--
-- Name: bills1980_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_s_ts_idx ON public.bills1980 USING gin (s_ts);


--
-- Name: bills1980_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_sconres_ts_idx ON public.bills1980 USING gin (sconres_ts);


--
-- Name: bills1980_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_sjres_ts_idx ON public.bills1980 USING gin (sjres_ts);


--
-- Name: bills1980_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_sres_ts_idx ON public.bills1980 USING gin (sres_ts);


--
-- Name: bills1980_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1980_statusat_idx ON public.bills1980 USING btree (statusat);


--
-- Name: bills1981_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_billtype_idx ON public.bills1981 USING btree (billtype);


--
-- Name: bills1981_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_hconres_ts_idx ON public.bills1981 USING gin (hconres_ts);


--
-- Name: bills1981_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_hjres_ts_idx ON public.bills1981 USING gin (hjres_ts);


--
-- Name: bills1981_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_hr_ts_idx ON public.bills1981 USING gin (hr_ts);


--
-- Name: bills1981_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_hres_ts_idx ON public.bills1981 USING gin (hres_ts);


--
-- Name: bills1981_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_s_ts_idx ON public.bills1981 USING gin (s_ts);


--
-- Name: bills1981_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_sconres_ts_idx ON public.bills1981 USING gin (sconres_ts);


--
-- Name: bills1981_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_sjres_ts_idx ON public.bills1981 USING gin (sjres_ts);


--
-- Name: bills1981_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_sres_ts_idx ON public.bills1981 USING gin (sres_ts);


--
-- Name: bills1981_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1981_statusat_idx ON public.bills1981 USING btree (statusat);


--
-- Name: bills1982_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_billtype_idx ON public.bills1982 USING btree (billtype);


--
-- Name: bills1982_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_hconres_ts_idx ON public.bills1982 USING gin (hconres_ts);


--
-- Name: bills1982_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_hjres_ts_idx ON public.bills1982 USING gin (hjres_ts);


--
-- Name: bills1982_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_hr_ts_idx ON public.bills1982 USING gin (hr_ts);


--
-- Name: bills1982_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_hres_ts_idx ON public.bills1982 USING gin (hres_ts);


--
-- Name: bills1982_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_s_ts_idx ON public.bills1982 USING gin (s_ts);


--
-- Name: bills1982_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_sconres_ts_idx ON public.bills1982 USING gin (sconres_ts);


--
-- Name: bills1982_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_sjres_ts_idx ON public.bills1982 USING gin (sjres_ts);


--
-- Name: bills1982_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_sres_ts_idx ON public.bills1982 USING gin (sres_ts);


--
-- Name: bills1982_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1982_statusat_idx ON public.bills1982 USING btree (statusat);


--
-- Name: bills1983_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_billtype_idx ON public.bills1983 USING btree (billtype);


--
-- Name: bills1983_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_hconres_ts_idx ON public.bills1983 USING gin (hconres_ts);


--
-- Name: bills1983_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_hjres_ts_idx ON public.bills1983 USING gin (hjres_ts);


--
-- Name: bills1983_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_hr_ts_idx ON public.bills1983 USING gin (hr_ts);


--
-- Name: bills1983_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_hres_ts_idx ON public.bills1983 USING gin (hres_ts);


--
-- Name: bills1983_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_s_ts_idx ON public.bills1983 USING gin (s_ts);


--
-- Name: bills1983_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_sconres_ts_idx ON public.bills1983 USING gin (sconres_ts);


--
-- Name: bills1983_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_sjres_ts_idx ON public.bills1983 USING gin (sjres_ts);


--
-- Name: bills1983_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_sres_ts_idx ON public.bills1983 USING gin (sres_ts);


--
-- Name: bills1983_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1983_statusat_idx ON public.bills1983 USING btree (statusat);


--
-- Name: bills1984_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_billtype_idx ON public.bills1984 USING btree (billtype);


--
-- Name: bills1984_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_hconres_ts_idx ON public.bills1984 USING gin (hconres_ts);


--
-- Name: bills1984_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_hjres_ts_idx ON public.bills1984 USING gin (hjres_ts);


--
-- Name: bills1984_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_hr_ts_idx ON public.bills1984 USING gin (hr_ts);


--
-- Name: bills1984_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_hres_ts_idx ON public.bills1984 USING gin (hres_ts);


--
-- Name: bills1984_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_s_ts_idx ON public.bills1984 USING gin (s_ts);


--
-- Name: bills1984_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_sconres_ts_idx ON public.bills1984 USING gin (sconres_ts);


--
-- Name: bills1984_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_sjres_ts_idx ON public.bills1984 USING gin (sjres_ts);


--
-- Name: bills1984_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_sres_ts_idx ON public.bills1984 USING gin (sres_ts);


--
-- Name: bills1984_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1984_statusat_idx ON public.bills1984 USING btree (statusat);


--
-- Name: bills1985_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_billtype_idx ON public.bills1985 USING btree (billtype);


--
-- Name: bills1985_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_hconres_ts_idx ON public.bills1985 USING gin (hconres_ts);


--
-- Name: bills1985_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_hjres_ts_idx ON public.bills1985 USING gin (hjres_ts);


--
-- Name: bills1985_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_hr_ts_idx ON public.bills1985 USING gin (hr_ts);


--
-- Name: bills1985_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_hres_ts_idx ON public.bills1985 USING gin (hres_ts);


--
-- Name: bills1985_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_s_ts_idx ON public.bills1985 USING gin (s_ts);


--
-- Name: bills1985_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_sconres_ts_idx ON public.bills1985 USING gin (sconres_ts);


--
-- Name: bills1985_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_sjres_ts_idx ON public.bills1985 USING gin (sjres_ts);


--
-- Name: bills1985_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_sres_ts_idx ON public.bills1985 USING gin (sres_ts);


--
-- Name: bills1985_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1985_statusat_idx ON public.bills1985 USING btree (statusat);


--
-- Name: bills1986_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_billtype_idx ON public.bills1986 USING btree (billtype);


--
-- Name: bills1986_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_hconres_ts_idx ON public.bills1986 USING gin (hconres_ts);


--
-- Name: bills1986_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_hjres_ts_idx ON public.bills1986 USING gin (hjres_ts);


--
-- Name: bills1986_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_hr_ts_idx ON public.bills1986 USING gin (hr_ts);


--
-- Name: bills1986_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_hres_ts_idx ON public.bills1986 USING gin (hres_ts);


--
-- Name: bills1986_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_s_ts_idx ON public.bills1986 USING gin (s_ts);


--
-- Name: bills1986_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_sconres_ts_idx ON public.bills1986 USING gin (sconres_ts);


--
-- Name: bills1986_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_sjres_ts_idx ON public.bills1986 USING gin (sjres_ts);


--
-- Name: bills1986_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_sres_ts_idx ON public.bills1986 USING gin (sres_ts);


--
-- Name: bills1986_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1986_statusat_idx ON public.bills1986 USING btree (statusat);


--
-- Name: bills1987_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_billtype_idx ON public.bills1987 USING btree (billtype);


--
-- Name: bills1987_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_hconres_ts_idx ON public.bills1987 USING gin (hconres_ts);


--
-- Name: bills1987_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_hjres_ts_idx ON public.bills1987 USING gin (hjres_ts);


--
-- Name: bills1987_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_hr_ts_idx ON public.bills1987 USING gin (hr_ts);


--
-- Name: bills1987_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_hres_ts_idx ON public.bills1987 USING gin (hres_ts);


--
-- Name: bills1987_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_s_ts_idx ON public.bills1987 USING gin (s_ts);


--
-- Name: bills1987_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_sconres_ts_idx ON public.bills1987 USING gin (sconres_ts);


--
-- Name: bills1987_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_sjres_ts_idx ON public.bills1987 USING gin (sjres_ts);


--
-- Name: bills1987_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_sres_ts_idx ON public.bills1987 USING gin (sres_ts);


--
-- Name: bills1987_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1987_statusat_idx ON public.bills1987 USING btree (statusat);


--
-- Name: bills1988_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_billtype_idx ON public.bills1988 USING btree (billtype);


--
-- Name: bills1988_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_hconres_ts_idx ON public.bills1988 USING gin (hconres_ts);


--
-- Name: bills1988_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_hjres_ts_idx ON public.bills1988 USING gin (hjres_ts);


--
-- Name: bills1988_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_hr_ts_idx ON public.bills1988 USING gin (hr_ts);


--
-- Name: bills1988_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_hres_ts_idx ON public.bills1988 USING gin (hres_ts);


--
-- Name: bills1988_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_s_ts_idx ON public.bills1988 USING gin (s_ts);


--
-- Name: bills1988_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_sconres_ts_idx ON public.bills1988 USING gin (sconres_ts);


--
-- Name: bills1988_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_sjres_ts_idx ON public.bills1988 USING gin (sjres_ts);


--
-- Name: bills1988_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_sres_ts_idx ON public.bills1988 USING gin (sres_ts);


--
-- Name: bills1988_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1988_statusat_idx ON public.bills1988 USING btree (statusat);


--
-- Name: bills1989_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_billtype_idx ON public.bills1989 USING btree (billtype);


--
-- Name: bills1989_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_hconres_ts_idx ON public.bills1989 USING gin (hconres_ts);


--
-- Name: bills1989_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_hjres_ts_idx ON public.bills1989 USING gin (hjres_ts);


--
-- Name: bills1989_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_hr_ts_idx ON public.bills1989 USING gin (hr_ts);


--
-- Name: bills1989_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_hres_ts_idx ON public.bills1989 USING gin (hres_ts);


--
-- Name: bills1989_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_s_ts_idx ON public.bills1989 USING gin (s_ts);


--
-- Name: bills1989_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_sconres_ts_idx ON public.bills1989 USING gin (sconres_ts);


--
-- Name: bills1989_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_sjres_ts_idx ON public.bills1989 USING gin (sjres_ts);


--
-- Name: bills1989_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_sres_ts_idx ON public.bills1989 USING gin (sres_ts);


--
-- Name: bills1989_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1989_statusat_idx ON public.bills1989 USING btree (statusat);


--
-- Name: bills1990_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_billtype_idx ON public.bills1990 USING btree (billtype);


--
-- Name: bills1990_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_hconres_ts_idx ON public.bills1990 USING gin (hconres_ts);


--
-- Name: bills1990_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_hjres_ts_idx ON public.bills1990 USING gin (hjres_ts);


--
-- Name: bills1990_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_hr_ts_idx ON public.bills1990 USING gin (hr_ts);


--
-- Name: bills1990_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_hres_ts_idx ON public.bills1990 USING gin (hres_ts);


--
-- Name: bills1990_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_s_ts_idx ON public.bills1990 USING gin (s_ts);


--
-- Name: bills1990_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_sconres_ts_idx ON public.bills1990 USING gin (sconres_ts);


--
-- Name: bills1990_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_sjres_ts_idx ON public.bills1990 USING gin (sjres_ts);


--
-- Name: bills1990_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_sres_ts_idx ON public.bills1990 USING gin (sres_ts);


--
-- Name: bills1990_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1990_statusat_idx ON public.bills1990 USING btree (statusat);


--
-- Name: bills1991_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_billtype_idx ON public.bills1991 USING btree (billtype);


--
-- Name: bills1991_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_hconres_ts_idx ON public.bills1991 USING gin (hconres_ts);


--
-- Name: bills1991_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_hjres_ts_idx ON public.bills1991 USING gin (hjres_ts);


--
-- Name: bills1991_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_hr_ts_idx ON public.bills1991 USING gin (hr_ts);


--
-- Name: bills1991_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_hres_ts_idx ON public.bills1991 USING gin (hres_ts);


--
-- Name: bills1991_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_s_ts_idx ON public.bills1991 USING gin (s_ts);


--
-- Name: bills1991_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_sconres_ts_idx ON public.bills1991 USING gin (sconres_ts);


--
-- Name: bills1991_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_sjres_ts_idx ON public.bills1991 USING gin (sjres_ts);


--
-- Name: bills1991_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_sres_ts_idx ON public.bills1991 USING gin (sres_ts);


--
-- Name: bills1991_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1991_statusat_idx ON public.bills1991 USING btree (statusat);


--
-- Name: bills1992_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_billtype_idx ON public.bills1992 USING btree (billtype);


--
-- Name: bills1992_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_hconres_ts_idx ON public.bills1992 USING gin (hconres_ts);


--
-- Name: bills1992_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_hjres_ts_idx ON public.bills1992 USING gin (hjres_ts);


--
-- Name: bills1992_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_hr_ts_idx ON public.bills1992 USING gin (hr_ts);


--
-- Name: bills1992_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_hres_ts_idx ON public.bills1992 USING gin (hres_ts);


--
-- Name: bills1992_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_s_ts_idx ON public.bills1992 USING gin (s_ts);


--
-- Name: bills1992_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_sconres_ts_idx ON public.bills1992 USING gin (sconres_ts);


--
-- Name: bills1992_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_sjres_ts_idx ON public.bills1992 USING gin (sjres_ts);


--
-- Name: bills1992_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_sres_ts_idx ON public.bills1992 USING gin (sres_ts);


--
-- Name: bills1992_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1992_statusat_idx ON public.bills1992 USING btree (statusat);


--
-- Name: bills1993_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_billtype_idx ON public.bills1993 USING btree (billtype);


--
-- Name: bills1993_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_hconres_ts_idx ON public.bills1993 USING gin (hconres_ts);


--
-- Name: bills1993_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_hjres_ts_idx ON public.bills1993 USING gin (hjres_ts);


--
-- Name: bills1993_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_hr_ts_idx ON public.bills1993 USING gin (hr_ts);


--
-- Name: bills1993_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_hres_ts_idx ON public.bills1993 USING gin (hres_ts);


--
-- Name: bills1993_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_s_ts_idx ON public.bills1993 USING gin (s_ts);


--
-- Name: bills1993_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_sconres_ts_idx ON public.bills1993 USING gin (sconres_ts);


--
-- Name: bills1993_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_sjres_ts_idx ON public.bills1993 USING gin (sjres_ts);


--
-- Name: bills1993_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_sres_ts_idx ON public.bills1993 USING gin (sres_ts);


--
-- Name: bills1993_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1993_statusat_idx ON public.bills1993 USING btree (statusat);


--
-- Name: bills1994_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_billtype_idx ON public.bills1994 USING btree (billtype);


--
-- Name: bills1994_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_hconres_ts_idx ON public.bills1994 USING gin (hconres_ts);


--
-- Name: bills1994_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_hjres_ts_idx ON public.bills1994 USING gin (hjres_ts);


--
-- Name: bills1994_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_hr_ts_idx ON public.bills1994 USING gin (hr_ts);


--
-- Name: bills1994_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_hres_ts_idx ON public.bills1994 USING gin (hres_ts);


--
-- Name: bills1994_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_s_ts_idx ON public.bills1994 USING gin (s_ts);


--
-- Name: bills1994_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_sconres_ts_idx ON public.bills1994 USING gin (sconres_ts);


--
-- Name: bills1994_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_sjres_ts_idx ON public.bills1994 USING gin (sjres_ts);


--
-- Name: bills1994_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_sres_ts_idx ON public.bills1994 USING gin (sres_ts);


--
-- Name: bills1994_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1994_statusat_idx ON public.bills1994 USING btree (statusat);


--
-- Name: bills1995_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_billtype_idx ON public.bills1995 USING btree (billtype);


--
-- Name: bills1995_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_hconres_ts_idx ON public.bills1995 USING gin (hconres_ts);


--
-- Name: bills1995_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_hjres_ts_idx ON public.bills1995 USING gin (hjres_ts);


--
-- Name: bills1995_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_hr_ts_idx ON public.bills1995 USING gin (hr_ts);


--
-- Name: bills1995_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_hres_ts_idx ON public.bills1995 USING gin (hres_ts);


--
-- Name: bills1995_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_s_ts_idx ON public.bills1995 USING gin (s_ts);


--
-- Name: bills1995_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_sconres_ts_idx ON public.bills1995 USING gin (sconres_ts);


--
-- Name: bills1995_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_sjres_ts_idx ON public.bills1995 USING gin (sjres_ts);


--
-- Name: bills1995_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_sres_ts_idx ON public.bills1995 USING gin (sres_ts);


--
-- Name: bills1995_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1995_statusat_idx ON public.bills1995 USING btree (statusat);


--
-- Name: bills1996_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_billtype_idx ON public.bills1996 USING btree (billtype);


--
-- Name: bills1996_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_hconres_ts_idx ON public.bills1996 USING gin (hconres_ts);


--
-- Name: bills1996_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_hjres_ts_idx ON public.bills1996 USING gin (hjres_ts);


--
-- Name: bills1996_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_hr_ts_idx ON public.bills1996 USING gin (hr_ts);


--
-- Name: bills1996_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_hres_ts_idx ON public.bills1996 USING gin (hres_ts);


--
-- Name: bills1996_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_s_ts_idx ON public.bills1996 USING gin (s_ts);


--
-- Name: bills1996_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_sconres_ts_idx ON public.bills1996 USING gin (sconres_ts);


--
-- Name: bills1996_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_sjres_ts_idx ON public.bills1996 USING gin (sjres_ts);


--
-- Name: bills1996_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_sres_ts_idx ON public.bills1996 USING gin (sres_ts);


--
-- Name: bills1996_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1996_statusat_idx ON public.bills1996 USING btree (statusat);


--
-- Name: bills1997_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_billtype_idx ON public.bills1997 USING btree (billtype);


--
-- Name: bills1997_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_hconres_ts_idx ON public.bills1997 USING gin (hconres_ts);


--
-- Name: bills1997_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_hjres_ts_idx ON public.bills1997 USING gin (hjres_ts);


--
-- Name: bills1997_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_hr_ts_idx ON public.bills1997 USING gin (hr_ts);


--
-- Name: bills1997_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_hres_ts_idx ON public.bills1997 USING gin (hres_ts);


--
-- Name: bills1997_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_s_ts_idx ON public.bills1997 USING gin (s_ts);


--
-- Name: bills1997_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_sconres_ts_idx ON public.bills1997 USING gin (sconres_ts);


--
-- Name: bills1997_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_sjres_ts_idx ON public.bills1997 USING gin (sjres_ts);


--
-- Name: bills1997_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_sres_ts_idx ON public.bills1997 USING gin (sres_ts);


--
-- Name: bills1997_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1997_statusat_idx ON public.bills1997 USING btree (statusat);


--
-- Name: bills1998_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_billtype_idx ON public.bills1998 USING btree (billtype);


--
-- Name: bills1998_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_hconres_ts_idx ON public.bills1998 USING gin (hconres_ts);


--
-- Name: bills1998_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_hjres_ts_idx ON public.bills1998 USING gin (hjres_ts);


--
-- Name: bills1998_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_hr_ts_idx ON public.bills1998 USING gin (hr_ts);


--
-- Name: bills1998_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_hres_ts_idx ON public.bills1998 USING gin (hres_ts);


--
-- Name: bills1998_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_s_ts_idx ON public.bills1998 USING gin (s_ts);


--
-- Name: bills1998_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_sconres_ts_idx ON public.bills1998 USING gin (sconres_ts);


--
-- Name: bills1998_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_sjres_ts_idx ON public.bills1998 USING gin (sjres_ts);


--
-- Name: bills1998_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_sres_ts_idx ON public.bills1998 USING gin (sres_ts);


--
-- Name: bills1998_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1998_statusat_idx ON public.bills1998 USING btree (statusat);


--
-- Name: bills1999_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_billtype_idx ON public.bills1999 USING btree (billtype);


--
-- Name: bills1999_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_hconres_ts_idx ON public.bills1999 USING gin (hconres_ts);


--
-- Name: bills1999_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_hjres_ts_idx ON public.bills1999 USING gin (hjres_ts);


--
-- Name: bills1999_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_hr_ts_idx ON public.bills1999 USING gin (hr_ts);


--
-- Name: bills1999_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_hres_ts_idx ON public.bills1999 USING gin (hres_ts);


--
-- Name: bills1999_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_s_ts_idx ON public.bills1999 USING gin (s_ts);


--
-- Name: bills1999_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_sconres_ts_idx ON public.bills1999 USING gin (sconres_ts);


--
-- Name: bills1999_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_sjres_ts_idx ON public.bills1999 USING gin (sjres_ts);


--
-- Name: bills1999_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_sres_ts_idx ON public.bills1999 USING gin (sres_ts);


--
-- Name: bills1999_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills1999_statusat_idx ON public.bills1999 USING btree (statusat);


--
-- Name: bills2000_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_billtype_idx ON public.bills2000 USING btree (billtype);


--
-- Name: bills2000_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_hconres_ts_idx ON public.bills2000 USING gin (hconres_ts);


--
-- Name: bills2000_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_hjres_ts_idx ON public.bills2000 USING gin (hjres_ts);


--
-- Name: bills2000_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_hr_ts_idx ON public.bills2000 USING gin (hr_ts);


--
-- Name: bills2000_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_hres_ts_idx ON public.bills2000 USING gin (hres_ts);


--
-- Name: bills2000_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_s_ts_idx ON public.bills2000 USING gin (s_ts);


--
-- Name: bills2000_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_sconres_ts_idx ON public.bills2000 USING gin (sconres_ts);


--
-- Name: bills2000_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_sjres_ts_idx ON public.bills2000 USING gin (sjres_ts);


--
-- Name: bills2000_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_sres_ts_idx ON public.bills2000 USING gin (sres_ts);


--
-- Name: bills2000_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2000_statusat_idx ON public.bills2000 USING btree (statusat);


--
-- Name: bills2001_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_billtype_idx ON public.bills2001 USING btree (billtype);


--
-- Name: bills2001_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_hconres_ts_idx ON public.bills2001 USING gin (hconres_ts);


--
-- Name: bills2001_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_hjres_ts_idx ON public.bills2001 USING gin (hjres_ts);


--
-- Name: bills2001_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_hr_ts_idx ON public.bills2001 USING gin (hr_ts);


--
-- Name: bills2001_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_hres_ts_idx ON public.bills2001 USING gin (hres_ts);


--
-- Name: bills2001_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_s_ts_idx ON public.bills2001 USING gin (s_ts);


--
-- Name: bills2001_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_sconres_ts_idx ON public.bills2001 USING gin (sconres_ts);


--
-- Name: bills2001_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_sjres_ts_idx ON public.bills2001 USING gin (sjres_ts);


--
-- Name: bills2001_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_sres_ts_idx ON public.bills2001 USING gin (sres_ts);


--
-- Name: bills2001_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2001_statusat_idx ON public.bills2001 USING btree (statusat);


--
-- Name: bills2002_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_billtype_idx ON public.bills2002 USING btree (billtype);


--
-- Name: bills2002_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_hconres_ts_idx ON public.bills2002 USING gin (hconres_ts);


--
-- Name: bills2002_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_hjres_ts_idx ON public.bills2002 USING gin (hjres_ts);


--
-- Name: bills2002_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_hr_ts_idx ON public.bills2002 USING gin (hr_ts);


--
-- Name: bills2002_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_hres_ts_idx ON public.bills2002 USING gin (hres_ts);


--
-- Name: bills2002_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_s_ts_idx ON public.bills2002 USING gin (s_ts);


--
-- Name: bills2002_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_sconres_ts_idx ON public.bills2002 USING gin (sconres_ts);


--
-- Name: bills2002_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_sjres_ts_idx ON public.bills2002 USING gin (sjres_ts);


--
-- Name: bills2002_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_sres_ts_idx ON public.bills2002 USING gin (sres_ts);


--
-- Name: bills2002_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2002_statusat_idx ON public.bills2002 USING btree (statusat);


--
-- Name: bills2003_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_billtype_idx ON public.bills2003 USING btree (billtype);


--
-- Name: bills2003_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_hconres_ts_idx ON public.bills2003 USING gin (hconres_ts);


--
-- Name: bills2003_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_hjres_ts_idx ON public.bills2003 USING gin (hjres_ts);


--
-- Name: bills2003_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_hr_ts_idx ON public.bills2003 USING gin (hr_ts);


--
-- Name: bills2003_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_hres_ts_idx ON public.bills2003 USING gin (hres_ts);


--
-- Name: bills2003_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_s_ts_idx ON public.bills2003 USING gin (s_ts);


--
-- Name: bills2003_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_sconres_ts_idx ON public.bills2003 USING gin (sconres_ts);


--
-- Name: bills2003_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_sjres_ts_idx ON public.bills2003 USING gin (sjres_ts);


--
-- Name: bills2003_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_sres_ts_idx ON public.bills2003 USING gin (sres_ts);


--
-- Name: bills2003_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2003_statusat_idx ON public.bills2003 USING btree (statusat);


--
-- Name: bills2004_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_billtype_idx ON public.bills2004 USING btree (billtype);


--
-- Name: bills2004_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_hconres_ts_idx ON public.bills2004 USING gin (hconres_ts);


--
-- Name: bills2004_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_hjres_ts_idx ON public.bills2004 USING gin (hjres_ts);


--
-- Name: bills2004_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_hr_ts_idx ON public.bills2004 USING gin (hr_ts);


--
-- Name: bills2004_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_hres_ts_idx ON public.bills2004 USING gin (hres_ts);


--
-- Name: bills2004_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_s_ts_idx ON public.bills2004 USING gin (s_ts);


--
-- Name: bills2004_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_sconres_ts_idx ON public.bills2004 USING gin (sconres_ts);


--
-- Name: bills2004_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_sjres_ts_idx ON public.bills2004 USING gin (sjres_ts);


--
-- Name: bills2004_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_sres_ts_idx ON public.bills2004 USING gin (sres_ts);


--
-- Name: bills2004_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2004_statusat_idx ON public.bills2004 USING btree (statusat);


--
-- Name: bills2005_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_billtype_idx ON public.bills2005 USING btree (billtype);


--
-- Name: bills2005_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_hconres_ts_idx ON public.bills2005 USING gin (hconres_ts);


--
-- Name: bills2005_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_hjres_ts_idx ON public.bills2005 USING gin (hjres_ts);


--
-- Name: bills2005_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_hr_ts_idx ON public.bills2005 USING gin (hr_ts);


--
-- Name: bills2005_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_hres_ts_idx ON public.bills2005 USING gin (hres_ts);


--
-- Name: bills2005_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_s_ts_idx ON public.bills2005 USING gin (s_ts);


--
-- Name: bills2005_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_sconres_ts_idx ON public.bills2005 USING gin (sconres_ts);


--
-- Name: bills2005_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_sjres_ts_idx ON public.bills2005 USING gin (sjres_ts);


--
-- Name: bills2005_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_sres_ts_idx ON public.bills2005 USING gin (sres_ts);


--
-- Name: bills2005_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2005_statusat_idx ON public.bills2005 USING btree (statusat);


--
-- Name: bills2006_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_billtype_idx ON public.bills2006 USING btree (billtype);


--
-- Name: bills2006_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_hconres_ts_idx ON public.bills2006 USING gin (hconres_ts);


--
-- Name: bills2006_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_hjres_ts_idx ON public.bills2006 USING gin (hjres_ts);


--
-- Name: bills2006_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_hr_ts_idx ON public.bills2006 USING gin (hr_ts);


--
-- Name: bills2006_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_hres_ts_idx ON public.bills2006 USING gin (hres_ts);


--
-- Name: bills2006_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_s_ts_idx ON public.bills2006 USING gin (s_ts);


--
-- Name: bills2006_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_sconres_ts_idx ON public.bills2006 USING gin (sconres_ts);


--
-- Name: bills2006_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_sjres_ts_idx ON public.bills2006 USING gin (sjres_ts);


--
-- Name: bills2006_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_sres_ts_idx ON public.bills2006 USING gin (sres_ts);


--
-- Name: bills2006_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2006_statusat_idx ON public.bills2006 USING btree (statusat);


--
-- Name: bills2007_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_billtype_idx ON public.bills2007 USING btree (billtype);


--
-- Name: bills2007_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_hconres_ts_idx ON public.bills2007 USING gin (hconres_ts);


--
-- Name: bills2007_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_hjres_ts_idx ON public.bills2007 USING gin (hjres_ts);


--
-- Name: bills2007_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_hr_ts_idx ON public.bills2007 USING gin (hr_ts);


--
-- Name: bills2007_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_hres_ts_idx ON public.bills2007 USING gin (hres_ts);


--
-- Name: bills2007_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_s_ts_idx ON public.bills2007 USING gin (s_ts);


--
-- Name: bills2007_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_sconres_ts_idx ON public.bills2007 USING gin (sconres_ts);


--
-- Name: bills2007_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_sjres_ts_idx ON public.bills2007 USING gin (sjres_ts);


--
-- Name: bills2007_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_sres_ts_idx ON public.bills2007 USING gin (sres_ts);


--
-- Name: bills2007_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2007_statusat_idx ON public.bills2007 USING btree (statusat);


--
-- Name: bills2008_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_billtype_idx ON public.bills2008 USING btree (billtype);


--
-- Name: bills2008_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_hconres_ts_idx ON public.bills2008 USING gin (hconres_ts);


--
-- Name: bills2008_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_hjres_ts_idx ON public.bills2008 USING gin (hjres_ts);


--
-- Name: bills2008_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_hr_ts_idx ON public.bills2008 USING gin (hr_ts);


--
-- Name: bills2008_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_hres_ts_idx ON public.bills2008 USING gin (hres_ts);


--
-- Name: bills2008_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_s_ts_idx ON public.bills2008 USING gin (s_ts);


--
-- Name: bills2008_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_sconres_ts_idx ON public.bills2008 USING gin (sconres_ts);


--
-- Name: bills2008_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_sjres_ts_idx ON public.bills2008 USING gin (sjres_ts);


--
-- Name: bills2008_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_sres_ts_idx ON public.bills2008 USING gin (sres_ts);


--
-- Name: bills2008_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2008_statusat_idx ON public.bills2008 USING btree (statusat);


--
-- Name: bills2009_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_billtype_idx ON public.bills2009 USING btree (billtype);


--
-- Name: bills2009_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_hconres_ts_idx ON public.bills2009 USING gin (hconres_ts);


--
-- Name: bills2009_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_hjres_ts_idx ON public.bills2009 USING gin (hjres_ts);


--
-- Name: bills2009_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_hr_ts_idx ON public.bills2009 USING gin (hr_ts);


--
-- Name: bills2009_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_hres_ts_idx ON public.bills2009 USING gin (hres_ts);


--
-- Name: bills2009_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_s_ts_idx ON public.bills2009 USING gin (s_ts);


--
-- Name: bills2009_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_sconres_ts_idx ON public.bills2009 USING gin (sconres_ts);


--
-- Name: bills2009_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_sjres_ts_idx ON public.bills2009 USING gin (sjres_ts);


--
-- Name: bills2009_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_sres_ts_idx ON public.bills2009 USING gin (sres_ts);


--
-- Name: bills2009_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2009_statusat_idx ON public.bills2009 USING btree (statusat);


--
-- Name: bills2010_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_billtype_idx ON public.bills2010 USING btree (billtype);


--
-- Name: bills2010_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_hconres_ts_idx ON public.bills2010 USING gin (hconres_ts);


--
-- Name: bills2010_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_hjres_ts_idx ON public.bills2010 USING gin (hjres_ts);


--
-- Name: bills2010_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_hr_ts_idx ON public.bills2010 USING gin (hr_ts);


--
-- Name: bills2010_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_hres_ts_idx ON public.bills2010 USING gin (hres_ts);


--
-- Name: bills2010_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_s_ts_idx ON public.bills2010 USING gin (s_ts);


--
-- Name: bills2010_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_sconres_ts_idx ON public.bills2010 USING gin (sconres_ts);


--
-- Name: bills2010_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_sjres_ts_idx ON public.bills2010 USING gin (sjres_ts);


--
-- Name: bills2010_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_sres_ts_idx ON public.bills2010 USING gin (sres_ts);


--
-- Name: bills2010_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2010_statusat_idx ON public.bills2010 USING btree (statusat);


--
-- Name: bills2011_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_billtype_idx ON public.bills2011 USING btree (billtype);


--
-- Name: bills2011_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_hconres_ts_idx ON public.bills2011 USING gin (hconres_ts);


--
-- Name: bills2011_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_hjres_ts_idx ON public.bills2011 USING gin (hjres_ts);


--
-- Name: bills2011_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_hr_ts_idx ON public.bills2011 USING gin (hr_ts);


--
-- Name: bills2011_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_hres_ts_idx ON public.bills2011 USING gin (hres_ts);


--
-- Name: bills2011_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_s_ts_idx ON public.bills2011 USING gin (s_ts);


--
-- Name: bills2011_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_sconres_ts_idx ON public.bills2011 USING gin (sconres_ts);


--
-- Name: bills2011_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_sjres_ts_idx ON public.bills2011 USING gin (sjres_ts);


--
-- Name: bills2011_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_sres_ts_idx ON public.bills2011 USING gin (sres_ts);


--
-- Name: bills2011_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2011_statusat_idx ON public.bills2011 USING btree (statusat);


--
-- Name: bills2012_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_billtype_idx ON public.bills2012 USING btree (billtype);


--
-- Name: bills2012_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_hconres_ts_idx ON public.bills2012 USING gin (hconres_ts);


--
-- Name: bills2012_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_hjres_ts_idx ON public.bills2012 USING gin (hjres_ts);


--
-- Name: bills2012_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_hr_ts_idx ON public.bills2012 USING gin (hr_ts);


--
-- Name: bills2012_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_hres_ts_idx ON public.bills2012 USING gin (hres_ts);


--
-- Name: bills2012_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_s_ts_idx ON public.bills2012 USING gin (s_ts);


--
-- Name: bills2012_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_sconres_ts_idx ON public.bills2012 USING gin (sconres_ts);


--
-- Name: bills2012_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_sjres_ts_idx ON public.bills2012 USING gin (sjres_ts);


--
-- Name: bills2012_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_sres_ts_idx ON public.bills2012 USING gin (sres_ts);


--
-- Name: bills2012_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2012_statusat_idx ON public.bills2012 USING btree (statusat);


--
-- Name: bills2013_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_billtype_idx ON public.bills2013 USING btree (billtype);


--
-- Name: bills2013_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_hconres_ts_idx ON public.bills2013 USING gin (hconres_ts);


--
-- Name: bills2013_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_hjres_ts_idx ON public.bills2013 USING gin (hjres_ts);


--
-- Name: bills2013_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_hr_ts_idx ON public.bills2013 USING gin (hr_ts);


--
-- Name: bills2013_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_hres_ts_idx ON public.bills2013 USING gin (hres_ts);


--
-- Name: bills2013_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_s_ts_idx ON public.bills2013 USING gin (s_ts);


--
-- Name: bills2013_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_sconres_ts_idx ON public.bills2013 USING gin (sconres_ts);


--
-- Name: bills2013_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_sjres_ts_idx ON public.bills2013 USING gin (sjres_ts);


--
-- Name: bills2013_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_sres_ts_idx ON public.bills2013 USING gin (sres_ts);


--
-- Name: bills2013_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2013_statusat_idx ON public.bills2013 USING btree (statusat);


--
-- Name: bills2014_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_billtype_idx ON public.bills2014 USING btree (billtype);


--
-- Name: bills2014_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_hconres_ts_idx ON public.bills2014 USING gin (hconres_ts);


--
-- Name: bills2014_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_hjres_ts_idx ON public.bills2014 USING gin (hjres_ts);


--
-- Name: bills2014_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_hr_ts_idx ON public.bills2014 USING gin (hr_ts);


--
-- Name: bills2014_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_hres_ts_idx ON public.bills2014 USING gin (hres_ts);


--
-- Name: bills2014_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_s_ts_idx ON public.bills2014 USING gin (s_ts);


--
-- Name: bills2014_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_sconres_ts_idx ON public.bills2014 USING gin (sconres_ts);


--
-- Name: bills2014_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_sjres_ts_idx ON public.bills2014 USING gin (sjres_ts);


--
-- Name: bills2014_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_sres_ts_idx ON public.bills2014 USING gin (sres_ts);


--
-- Name: bills2014_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2014_statusat_idx ON public.bills2014 USING btree (statusat);


--
-- Name: bills2015_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_billtype_idx ON public.bills2015 USING btree (billtype);


--
-- Name: bills2015_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_hconres_ts_idx ON public.bills2015 USING gin (hconres_ts);


--
-- Name: bills2015_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_hjres_ts_idx ON public.bills2015 USING gin (hjres_ts);


--
-- Name: bills2015_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_hr_ts_idx ON public.bills2015 USING gin (hr_ts);


--
-- Name: bills2015_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_hres_ts_idx ON public.bills2015 USING gin (hres_ts);


--
-- Name: bills2015_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_s_ts_idx ON public.bills2015 USING gin (s_ts);


--
-- Name: bills2015_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_sconres_ts_idx ON public.bills2015 USING gin (sconres_ts);


--
-- Name: bills2015_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_sjres_ts_idx ON public.bills2015 USING gin (sjres_ts);


--
-- Name: bills2015_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_sres_ts_idx ON public.bills2015 USING gin (sres_ts);


--
-- Name: bills2015_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2015_statusat_idx ON public.bills2015 USING btree (statusat);


--
-- Name: bills2016_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_billtype_idx ON public.bills2016 USING btree (billtype);


--
-- Name: bills2016_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_hconres_ts_idx ON public.bills2016 USING gin (hconres_ts);


--
-- Name: bills2016_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_hjres_ts_idx ON public.bills2016 USING gin (hjres_ts);


--
-- Name: bills2016_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_hr_ts_idx ON public.bills2016 USING gin (hr_ts);


--
-- Name: bills2016_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_hres_ts_idx ON public.bills2016 USING gin (hres_ts);


--
-- Name: bills2016_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_s_ts_idx ON public.bills2016 USING gin (s_ts);


--
-- Name: bills2016_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_sconres_ts_idx ON public.bills2016 USING gin (sconres_ts);


--
-- Name: bills2016_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_sjres_ts_idx ON public.bills2016 USING gin (sjres_ts);


--
-- Name: bills2016_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_sres_ts_idx ON public.bills2016 USING gin (sres_ts);


--
-- Name: bills2016_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2016_statusat_idx ON public.bills2016 USING btree (statusat);


--
-- Name: bills2017_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_billtype_idx ON public.bills2017 USING btree (billtype);


--
-- Name: bills2017_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_hconres_ts_idx ON public.bills2017 USING gin (hconres_ts);


--
-- Name: bills2017_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_hjres_ts_idx ON public.bills2017 USING gin (hjres_ts);


--
-- Name: bills2017_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_hr_ts_idx ON public.bills2017 USING gin (hr_ts);


--
-- Name: bills2017_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_hres_ts_idx ON public.bills2017 USING gin (hres_ts);


--
-- Name: bills2017_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_s_ts_idx ON public.bills2017 USING gin (s_ts);


--
-- Name: bills2017_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_sconres_ts_idx ON public.bills2017 USING gin (sconres_ts);


--
-- Name: bills2017_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_sjres_ts_idx ON public.bills2017 USING gin (sjres_ts);


--
-- Name: bills2017_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_sres_ts_idx ON public.bills2017 USING gin (sres_ts);


--
-- Name: bills2017_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2017_statusat_idx ON public.bills2017 USING btree (statusat);


--
-- Name: bills2018_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_billtype_idx ON public.bills2018 USING btree (billtype);


--
-- Name: bills2018_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_hconres_ts_idx ON public.bills2018 USING gin (hconres_ts);


--
-- Name: bills2018_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_hjres_ts_idx ON public.bills2018 USING gin (hjres_ts);


--
-- Name: bills2018_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_hr_ts_idx ON public.bills2018 USING gin (hr_ts);


--
-- Name: bills2018_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_hres_ts_idx ON public.bills2018 USING gin (hres_ts);


--
-- Name: bills2018_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_s_ts_idx ON public.bills2018 USING gin (s_ts);


--
-- Name: bills2018_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_sconres_ts_idx ON public.bills2018 USING gin (sconres_ts);


--
-- Name: bills2018_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_sjres_ts_idx ON public.bills2018 USING gin (sjres_ts);


--
-- Name: bills2018_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_sres_ts_idx ON public.bills2018 USING gin (sres_ts);


--
-- Name: bills2018_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2018_statusat_idx ON public.bills2018 USING btree (statusat);


--
-- Name: bills2019_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_billtype_idx ON public.bills2019 USING btree (billtype);


--
-- Name: bills2019_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_hconres_ts_idx ON public.bills2019 USING gin (hconres_ts);


--
-- Name: bills2019_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_hjres_ts_idx ON public.bills2019 USING gin (hjres_ts);


--
-- Name: bills2019_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_hr_ts_idx ON public.bills2019 USING gin (hr_ts);


--
-- Name: bills2019_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_hres_ts_idx ON public.bills2019 USING gin (hres_ts);


--
-- Name: bills2019_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_s_ts_idx ON public.bills2019 USING gin (s_ts);


--
-- Name: bills2019_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_sconres_ts_idx ON public.bills2019 USING gin (sconres_ts);


--
-- Name: bills2019_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_sjres_ts_idx ON public.bills2019 USING gin (sjres_ts);


--
-- Name: bills2019_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_sres_ts_idx ON public.bills2019 USING gin (sres_ts);


--
-- Name: bills2019_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2019_statusat_idx ON public.bills2019 USING btree (statusat);


--
-- Name: bills2020_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_billtype_idx ON public.bills2020 USING btree (billtype);


--
-- Name: bills2020_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_hconres_ts_idx ON public.bills2020 USING gin (hconres_ts);


--
-- Name: bills2020_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_hjres_ts_idx ON public.bills2020 USING gin (hjres_ts);


--
-- Name: bills2020_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_hr_ts_idx ON public.bills2020 USING gin (hr_ts);


--
-- Name: bills2020_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_hres_ts_idx ON public.bills2020 USING gin (hres_ts);


--
-- Name: bills2020_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_s_ts_idx ON public.bills2020 USING gin (s_ts);


--
-- Name: bills2020_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_sconres_ts_idx ON public.bills2020 USING gin (sconres_ts);


--
-- Name: bills2020_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_sjres_ts_idx ON public.bills2020 USING gin (sjres_ts);


--
-- Name: bills2020_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_sres_ts_idx ON public.bills2020 USING gin (sres_ts);


--
-- Name: bills2020_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2020_statusat_idx ON public.bills2020 USING btree (statusat);


--
-- Name: bills2021_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_billtype_idx ON public.bills2021 USING btree (billtype);


--
-- Name: bills2021_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_hconres_ts_idx ON public.bills2021 USING gin (hconres_ts);


--
-- Name: bills2021_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_hjres_ts_idx ON public.bills2021 USING gin (hjres_ts);


--
-- Name: bills2021_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_hr_ts_idx ON public.bills2021 USING gin (hr_ts);


--
-- Name: bills2021_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_hres_ts_idx ON public.bills2021 USING gin (hres_ts);


--
-- Name: bills2021_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_s_ts_idx ON public.bills2021 USING gin (s_ts);


--
-- Name: bills2021_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_sconres_ts_idx ON public.bills2021 USING gin (sconres_ts);


--
-- Name: bills2021_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_sjres_ts_idx ON public.bills2021 USING gin (sjres_ts);


--
-- Name: bills2021_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_sres_ts_idx ON public.bills2021 USING gin (sres_ts);


--
-- Name: bills2021_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2021_statusat_idx ON public.bills2021 USING btree (statusat);


--
-- Name: bills2022_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_billtype_idx ON public.bills2022 USING btree (billtype);


--
-- Name: bills2022_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_hconres_ts_idx ON public.bills2022 USING gin (hconres_ts);


--
-- Name: bills2022_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_hjres_ts_idx ON public.bills2022 USING gin (hjres_ts);


--
-- Name: bills2022_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_hr_ts_idx ON public.bills2022 USING gin (hr_ts);


--
-- Name: bills2022_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_hres_ts_idx ON public.bills2022 USING gin (hres_ts);


--
-- Name: bills2022_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_s_ts_idx ON public.bills2022 USING gin (s_ts);


--
-- Name: bills2022_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_sconres_ts_idx ON public.bills2022 USING gin (sconres_ts);


--
-- Name: bills2022_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_sjres_ts_idx ON public.bills2022 USING gin (sjres_ts);


--
-- Name: bills2022_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_sres_ts_idx ON public.bills2022 USING gin (sres_ts);


--
-- Name: bills2022_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2022_statusat_idx ON public.bills2022 USING btree (statusat);


--
-- Name: bills2023_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_billtype_idx ON public.bills2023 USING btree (billtype);


--
-- Name: bills2023_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_hconres_ts_idx ON public.bills2023 USING gin (hconres_ts);


--
-- Name: bills2023_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_hjres_ts_idx ON public.bills2023 USING gin (hjres_ts);


--
-- Name: bills2023_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_hr_ts_idx ON public.bills2023 USING gin (hr_ts);


--
-- Name: bills2023_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_hres_ts_idx ON public.bills2023 USING gin (hres_ts);


--
-- Name: bills2023_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_s_ts_idx ON public.bills2023 USING gin (s_ts);


--
-- Name: bills2023_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_sconres_ts_idx ON public.bills2023 USING gin (sconres_ts);


--
-- Name: bills2023_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_sjres_ts_idx ON public.bills2023 USING gin (sjres_ts);


--
-- Name: bills2023_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_sres_ts_idx ON public.bills2023 USING gin (sres_ts);


--
-- Name: bills2023_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2023_statusat_idx ON public.bills2023 USING btree (statusat);


--
-- Name: bills2024_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_billtype_idx ON public.bills2024 USING btree (billtype);


--
-- Name: bills2024_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_hconres_ts_idx ON public.bills2024 USING gin (hconres_ts);


--
-- Name: bills2024_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_hjres_ts_idx ON public.bills2024 USING gin (hjres_ts);


--
-- Name: bills2024_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_hr_ts_idx ON public.bills2024 USING gin (hr_ts);


--
-- Name: bills2024_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_hres_ts_idx ON public.bills2024 USING gin (hres_ts);


--
-- Name: bills2024_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_s_ts_idx ON public.bills2024 USING gin (s_ts);


--
-- Name: bills2024_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_sconres_ts_idx ON public.bills2024 USING gin (sconres_ts);


--
-- Name: bills2024_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_sjres_ts_idx ON public.bills2024 USING gin (sjres_ts);


--
-- Name: bills2024_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_sres_ts_idx ON public.bills2024 USING gin (sres_ts);


--
-- Name: bills2024_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2024_statusat_idx ON public.bills2024 USING btree (statusat);


--
-- Name: bills2025_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_billtype_idx ON public.bills2025 USING btree (billtype);


--
-- Name: bills2025_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_hconres_ts_idx ON public.bills2025 USING gin (hconres_ts);


--
-- Name: bills2025_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_hjres_ts_idx ON public.bills2025 USING gin (hjres_ts);


--
-- Name: bills2025_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_hr_ts_idx ON public.bills2025 USING gin (hr_ts);


--
-- Name: bills2025_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_hres_ts_idx ON public.bills2025 USING gin (hres_ts);


--
-- Name: bills2025_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_s_ts_idx ON public.bills2025 USING gin (s_ts);


--
-- Name: bills2025_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_sconres_ts_idx ON public.bills2025 USING gin (sconres_ts);


--
-- Name: bills2025_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_sjres_ts_idx ON public.bills2025 USING gin (sjres_ts);


--
-- Name: bills2025_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_sres_ts_idx ON public.bills2025 USING gin (sres_ts);


--
-- Name: bills2025_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2025_statusat_idx ON public.bills2025 USING btree (statusat);


--
-- Name: bills2026_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_billtype_idx ON public.bills2026 USING btree (billtype);


--
-- Name: bills2026_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_hconres_ts_idx ON public.bills2026 USING gin (hconres_ts);


--
-- Name: bills2026_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_hjres_ts_idx ON public.bills2026 USING gin (hjres_ts);


--
-- Name: bills2026_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_hr_ts_idx ON public.bills2026 USING gin (hr_ts);


--
-- Name: bills2026_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_hres_ts_idx ON public.bills2026 USING gin (hres_ts);


--
-- Name: bills2026_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_s_ts_idx ON public.bills2026 USING gin (s_ts);


--
-- Name: bills2026_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_sconres_ts_idx ON public.bills2026 USING gin (sconres_ts);


--
-- Name: bills2026_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_sjres_ts_idx ON public.bills2026 USING gin (sjres_ts);


--
-- Name: bills2026_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_sres_ts_idx ON public.bills2026 USING gin (sres_ts);


--
-- Name: bills2026_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2026_statusat_idx ON public.bills2026 USING btree (statusat);


--
-- Name: bills2027_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_billtype_idx ON public.bills2027 USING btree (billtype);


--
-- Name: bills2027_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_hconres_ts_idx ON public.bills2027 USING gin (hconres_ts);


--
-- Name: bills2027_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_hjres_ts_idx ON public.bills2027 USING gin (hjres_ts);


--
-- Name: bills2027_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_hr_ts_idx ON public.bills2027 USING gin (hr_ts);


--
-- Name: bills2027_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_hres_ts_idx ON public.bills2027 USING gin (hres_ts);


--
-- Name: bills2027_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_s_ts_idx ON public.bills2027 USING gin (s_ts);


--
-- Name: bills2027_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_sconres_ts_idx ON public.bills2027 USING gin (sconres_ts);


--
-- Name: bills2027_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_sjres_ts_idx ON public.bills2027 USING gin (sjres_ts);


--
-- Name: bills2027_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_sres_ts_idx ON public.bills2027 USING gin (sres_ts);


--
-- Name: bills2027_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2027_statusat_idx ON public.bills2027 USING btree (statusat);


--
-- Name: bills2028_billtype_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_billtype_idx ON public.bills2028 USING btree (billtype);


--
-- Name: bills2028_hconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_hconres_ts_idx ON public.bills2028 USING gin (hconres_ts);


--
-- Name: bills2028_hjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_hjres_ts_idx ON public.bills2028 USING gin (hjres_ts);


--
-- Name: bills2028_hr_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_hr_ts_idx ON public.bills2028 USING gin (hr_ts);


--
-- Name: bills2028_hres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_hres_ts_idx ON public.bills2028 USING gin (hres_ts);


--
-- Name: bills2028_s_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_s_ts_idx ON public.bills2028 USING gin (s_ts);


--
-- Name: bills2028_sconres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_sconres_ts_idx ON public.bills2028 USING gin (sconres_ts);


--
-- Name: bills2028_sjres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_sjres_ts_idx ON public.bills2028 USING gin (sjres_ts);


--
-- Name: bills2028_sres_ts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_sres_ts_idx ON public.bills2028 USING gin (sres_ts);


--
-- Name: bills2028_statusat_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bills2028_statusat_idx ON public.bills2028 USING btree (statusat);


--
-- Name: bills1973_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1973_billtype_idx;


--
-- Name: bills1973_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1973_hconres_ts_idx;


--
-- Name: bills1973_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1973_hjres_ts_idx;


--
-- Name: bills1973_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1973_hr_ts_idx;


--
-- Name: bills1973_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1973_hres_ts_idx;


--
-- Name: bills1973_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1973_pkey;


--
-- Name: bills1973_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1973_s_ts_idx;


--
-- Name: bills1973_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1973_sconres_ts_idx;


--
-- Name: bills1973_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1973_sjres_ts_idx;


--
-- Name: bills1973_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1973_sres_ts_idx;


--
-- Name: bills1973_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1973_statusat_idx;


--
-- Name: bills1974_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1974_billtype_idx;


--
-- Name: bills1974_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1974_hconres_ts_idx;


--
-- Name: bills1974_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1974_hjres_ts_idx;


--
-- Name: bills1974_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1974_hr_ts_idx;


--
-- Name: bills1974_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1974_hres_ts_idx;


--
-- Name: bills1974_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1974_pkey;


--
-- Name: bills1974_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1974_s_ts_idx;


--
-- Name: bills1974_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1974_sconres_ts_idx;


--
-- Name: bills1974_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1974_sjres_ts_idx;


--
-- Name: bills1974_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1974_sres_ts_idx;


--
-- Name: bills1974_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1974_statusat_idx;


--
-- Name: bills1975_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1975_billtype_idx;


--
-- Name: bills1975_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1975_hconres_ts_idx;


--
-- Name: bills1975_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1975_hjres_ts_idx;


--
-- Name: bills1975_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1975_hr_ts_idx;


--
-- Name: bills1975_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1975_hres_ts_idx;


--
-- Name: bills1975_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1975_pkey;


--
-- Name: bills1975_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1975_s_ts_idx;


--
-- Name: bills1975_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1975_sconres_ts_idx;


--
-- Name: bills1975_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1975_sjres_ts_idx;


--
-- Name: bills1975_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1975_sres_ts_idx;


--
-- Name: bills1975_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1975_statusat_idx;


--
-- Name: bills1976_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1976_billtype_idx;


--
-- Name: bills1976_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1976_hconres_ts_idx;


--
-- Name: bills1976_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1976_hjres_ts_idx;


--
-- Name: bills1976_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1976_hr_ts_idx;


--
-- Name: bills1976_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1976_hres_ts_idx;


--
-- Name: bills1976_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1976_pkey;


--
-- Name: bills1976_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1976_s_ts_idx;


--
-- Name: bills1976_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1976_sconres_ts_idx;


--
-- Name: bills1976_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1976_sjres_ts_idx;


--
-- Name: bills1976_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1976_sres_ts_idx;


--
-- Name: bills1976_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1976_statusat_idx;


--
-- Name: bills1977_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1977_billtype_idx;


--
-- Name: bills1977_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1977_hconres_ts_idx;


--
-- Name: bills1977_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1977_hjres_ts_idx;


--
-- Name: bills1977_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1977_hr_ts_idx;


--
-- Name: bills1977_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1977_hres_ts_idx;


--
-- Name: bills1977_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1977_pkey;


--
-- Name: bills1977_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1977_s_ts_idx;


--
-- Name: bills1977_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1977_sconres_ts_idx;


--
-- Name: bills1977_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1977_sjres_ts_idx;


--
-- Name: bills1977_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1977_sres_ts_idx;


--
-- Name: bills1977_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1977_statusat_idx;


--
-- Name: bills1978_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1978_billtype_idx;


--
-- Name: bills1978_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1978_hconres_ts_idx;


--
-- Name: bills1978_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1978_hjres_ts_idx;


--
-- Name: bills1978_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1978_hr_ts_idx;


--
-- Name: bills1978_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1978_hres_ts_idx;


--
-- Name: bills1978_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1978_pkey;


--
-- Name: bills1978_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1978_s_ts_idx;


--
-- Name: bills1978_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1978_sconres_ts_idx;


--
-- Name: bills1978_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1978_sjres_ts_idx;


--
-- Name: bills1978_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1978_sres_ts_idx;


--
-- Name: bills1978_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1978_statusat_idx;


--
-- Name: bills1979_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1979_billtype_idx;


--
-- Name: bills1979_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1979_hconres_ts_idx;


--
-- Name: bills1979_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1979_hjres_ts_idx;


--
-- Name: bills1979_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1979_hr_ts_idx;


--
-- Name: bills1979_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1979_hres_ts_idx;


--
-- Name: bills1979_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1979_pkey;


--
-- Name: bills1979_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1979_s_ts_idx;


--
-- Name: bills1979_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1979_sconres_ts_idx;


--
-- Name: bills1979_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1979_sjres_ts_idx;


--
-- Name: bills1979_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1979_sres_ts_idx;


--
-- Name: bills1979_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1979_statusat_idx;


--
-- Name: bills1980_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1980_billtype_idx;


--
-- Name: bills1980_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1980_hconres_ts_idx;


--
-- Name: bills1980_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1980_hjres_ts_idx;


--
-- Name: bills1980_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1980_hr_ts_idx;


--
-- Name: bills1980_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1980_hres_ts_idx;


--
-- Name: bills1980_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1980_pkey;


--
-- Name: bills1980_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1980_s_ts_idx;


--
-- Name: bills1980_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1980_sconres_ts_idx;


--
-- Name: bills1980_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1980_sjres_ts_idx;


--
-- Name: bills1980_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1980_sres_ts_idx;


--
-- Name: bills1980_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1980_statusat_idx;


--
-- Name: bills1981_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1981_billtype_idx;


--
-- Name: bills1981_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1981_hconres_ts_idx;


--
-- Name: bills1981_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1981_hjres_ts_idx;


--
-- Name: bills1981_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1981_hr_ts_idx;


--
-- Name: bills1981_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1981_hres_ts_idx;


--
-- Name: bills1981_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1981_pkey;


--
-- Name: bills1981_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1981_s_ts_idx;


--
-- Name: bills1981_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1981_sconres_ts_idx;


--
-- Name: bills1981_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1981_sjres_ts_idx;


--
-- Name: bills1981_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1981_sres_ts_idx;


--
-- Name: bills1981_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1981_statusat_idx;


--
-- Name: bills1982_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1982_billtype_idx;


--
-- Name: bills1982_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1982_hconres_ts_idx;


--
-- Name: bills1982_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1982_hjres_ts_idx;


--
-- Name: bills1982_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1982_hr_ts_idx;


--
-- Name: bills1982_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1982_hres_ts_idx;


--
-- Name: bills1982_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1982_pkey;


--
-- Name: bills1982_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1982_s_ts_idx;


--
-- Name: bills1982_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1982_sconres_ts_idx;


--
-- Name: bills1982_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1982_sjres_ts_idx;


--
-- Name: bills1982_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1982_sres_ts_idx;


--
-- Name: bills1982_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1982_statusat_idx;


--
-- Name: bills1983_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1983_billtype_idx;


--
-- Name: bills1983_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1983_hconres_ts_idx;


--
-- Name: bills1983_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1983_hjres_ts_idx;


--
-- Name: bills1983_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1983_hr_ts_idx;


--
-- Name: bills1983_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1983_hres_ts_idx;


--
-- Name: bills1983_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1983_pkey;


--
-- Name: bills1983_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1983_s_ts_idx;


--
-- Name: bills1983_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1983_sconres_ts_idx;


--
-- Name: bills1983_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1983_sjres_ts_idx;


--
-- Name: bills1983_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1983_sres_ts_idx;


--
-- Name: bills1983_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1983_statusat_idx;


--
-- Name: bills1984_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1984_billtype_idx;


--
-- Name: bills1984_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1984_hconres_ts_idx;


--
-- Name: bills1984_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1984_hjres_ts_idx;


--
-- Name: bills1984_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1984_hr_ts_idx;


--
-- Name: bills1984_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1984_hres_ts_idx;


--
-- Name: bills1984_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1984_pkey;


--
-- Name: bills1984_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1984_s_ts_idx;


--
-- Name: bills1984_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1984_sconres_ts_idx;


--
-- Name: bills1984_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1984_sjres_ts_idx;


--
-- Name: bills1984_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1984_sres_ts_idx;


--
-- Name: bills1984_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1984_statusat_idx;


--
-- Name: bills1985_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1985_billtype_idx;


--
-- Name: bills1985_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1985_hconres_ts_idx;


--
-- Name: bills1985_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1985_hjres_ts_idx;


--
-- Name: bills1985_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1985_hr_ts_idx;


--
-- Name: bills1985_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1985_hres_ts_idx;


--
-- Name: bills1985_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1985_pkey;


--
-- Name: bills1985_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1985_s_ts_idx;


--
-- Name: bills1985_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1985_sconres_ts_idx;


--
-- Name: bills1985_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1985_sjres_ts_idx;


--
-- Name: bills1985_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1985_sres_ts_idx;


--
-- Name: bills1985_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1985_statusat_idx;


--
-- Name: bills1986_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1986_billtype_idx;


--
-- Name: bills1986_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1986_hconres_ts_idx;


--
-- Name: bills1986_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1986_hjres_ts_idx;


--
-- Name: bills1986_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1986_hr_ts_idx;


--
-- Name: bills1986_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1986_hres_ts_idx;


--
-- Name: bills1986_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1986_pkey;


--
-- Name: bills1986_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1986_s_ts_idx;


--
-- Name: bills1986_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1986_sconres_ts_idx;


--
-- Name: bills1986_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1986_sjres_ts_idx;


--
-- Name: bills1986_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1986_sres_ts_idx;


--
-- Name: bills1986_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1986_statusat_idx;


--
-- Name: bills1987_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1987_billtype_idx;


--
-- Name: bills1987_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1987_hconres_ts_idx;


--
-- Name: bills1987_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1987_hjres_ts_idx;


--
-- Name: bills1987_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1987_hr_ts_idx;


--
-- Name: bills1987_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1987_hres_ts_idx;


--
-- Name: bills1987_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1987_pkey;


--
-- Name: bills1987_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1987_s_ts_idx;


--
-- Name: bills1987_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1987_sconres_ts_idx;


--
-- Name: bills1987_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1987_sjres_ts_idx;


--
-- Name: bills1987_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1987_sres_ts_idx;


--
-- Name: bills1987_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1987_statusat_idx;


--
-- Name: bills1988_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1988_billtype_idx;


--
-- Name: bills1988_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1988_hconres_ts_idx;


--
-- Name: bills1988_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1988_hjres_ts_idx;


--
-- Name: bills1988_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1988_hr_ts_idx;


--
-- Name: bills1988_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1988_hres_ts_idx;


--
-- Name: bills1988_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1988_pkey;


--
-- Name: bills1988_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1988_s_ts_idx;


--
-- Name: bills1988_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1988_sconres_ts_idx;


--
-- Name: bills1988_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1988_sjres_ts_idx;


--
-- Name: bills1988_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1988_sres_ts_idx;


--
-- Name: bills1988_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1988_statusat_idx;


--
-- Name: bills1989_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1989_billtype_idx;


--
-- Name: bills1989_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1989_hconres_ts_idx;


--
-- Name: bills1989_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1989_hjres_ts_idx;


--
-- Name: bills1989_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1989_hr_ts_idx;


--
-- Name: bills1989_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1989_hres_ts_idx;


--
-- Name: bills1989_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1989_pkey;


--
-- Name: bills1989_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1989_s_ts_idx;


--
-- Name: bills1989_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1989_sconres_ts_idx;


--
-- Name: bills1989_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1989_sjres_ts_idx;


--
-- Name: bills1989_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1989_sres_ts_idx;


--
-- Name: bills1989_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1989_statusat_idx;


--
-- Name: bills1990_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1990_billtype_idx;


--
-- Name: bills1990_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1990_hconres_ts_idx;


--
-- Name: bills1990_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1990_hjres_ts_idx;


--
-- Name: bills1990_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1990_hr_ts_idx;


--
-- Name: bills1990_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1990_hres_ts_idx;


--
-- Name: bills1990_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1990_pkey;


--
-- Name: bills1990_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1990_s_ts_idx;


--
-- Name: bills1990_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1990_sconres_ts_idx;


--
-- Name: bills1990_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1990_sjres_ts_idx;


--
-- Name: bills1990_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1990_sres_ts_idx;


--
-- Name: bills1990_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1990_statusat_idx;


--
-- Name: bills1991_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1991_billtype_idx;


--
-- Name: bills1991_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1991_hconres_ts_idx;


--
-- Name: bills1991_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1991_hjres_ts_idx;


--
-- Name: bills1991_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1991_hr_ts_idx;


--
-- Name: bills1991_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1991_hres_ts_idx;


--
-- Name: bills1991_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1991_pkey;


--
-- Name: bills1991_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1991_s_ts_idx;


--
-- Name: bills1991_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1991_sconres_ts_idx;


--
-- Name: bills1991_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1991_sjres_ts_idx;


--
-- Name: bills1991_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1991_sres_ts_idx;


--
-- Name: bills1991_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1991_statusat_idx;


--
-- Name: bills1992_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1992_billtype_idx;


--
-- Name: bills1992_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1992_hconres_ts_idx;


--
-- Name: bills1992_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1992_hjres_ts_idx;


--
-- Name: bills1992_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1992_hr_ts_idx;


--
-- Name: bills1992_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1992_hres_ts_idx;


--
-- Name: bills1992_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1992_pkey;


--
-- Name: bills1992_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1992_s_ts_idx;


--
-- Name: bills1992_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1992_sconres_ts_idx;


--
-- Name: bills1992_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1992_sjres_ts_idx;


--
-- Name: bills1992_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1992_sres_ts_idx;


--
-- Name: bills1992_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1992_statusat_idx;


--
-- Name: bills1993_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1993_billtype_idx;


--
-- Name: bills1993_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1993_hconres_ts_idx;


--
-- Name: bills1993_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1993_hjres_ts_idx;


--
-- Name: bills1993_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1993_hr_ts_idx;


--
-- Name: bills1993_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1993_hres_ts_idx;


--
-- Name: bills1993_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1993_pkey;


--
-- Name: bills1993_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1993_s_ts_idx;


--
-- Name: bills1993_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1993_sconres_ts_idx;


--
-- Name: bills1993_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1993_sjres_ts_idx;


--
-- Name: bills1993_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1993_sres_ts_idx;


--
-- Name: bills1993_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1993_statusat_idx;


--
-- Name: bills1994_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1994_billtype_idx;


--
-- Name: bills1994_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1994_hconres_ts_idx;


--
-- Name: bills1994_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1994_hjres_ts_idx;


--
-- Name: bills1994_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1994_hr_ts_idx;


--
-- Name: bills1994_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1994_hres_ts_idx;


--
-- Name: bills1994_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1994_pkey;


--
-- Name: bills1994_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1994_s_ts_idx;


--
-- Name: bills1994_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1994_sconres_ts_idx;


--
-- Name: bills1994_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1994_sjres_ts_idx;


--
-- Name: bills1994_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1994_sres_ts_idx;


--
-- Name: bills1994_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1994_statusat_idx;


--
-- Name: bills1995_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1995_billtype_idx;


--
-- Name: bills1995_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1995_hconres_ts_idx;


--
-- Name: bills1995_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1995_hjres_ts_idx;


--
-- Name: bills1995_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1995_hr_ts_idx;


--
-- Name: bills1995_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1995_hres_ts_idx;


--
-- Name: bills1995_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1995_pkey;


--
-- Name: bills1995_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1995_s_ts_idx;


--
-- Name: bills1995_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1995_sconres_ts_idx;


--
-- Name: bills1995_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1995_sjres_ts_idx;


--
-- Name: bills1995_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1995_sres_ts_idx;


--
-- Name: bills1995_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1995_statusat_idx;


--
-- Name: bills1996_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1996_billtype_idx;


--
-- Name: bills1996_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1996_hconres_ts_idx;


--
-- Name: bills1996_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1996_hjres_ts_idx;


--
-- Name: bills1996_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1996_hr_ts_idx;


--
-- Name: bills1996_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1996_hres_ts_idx;


--
-- Name: bills1996_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1996_pkey;


--
-- Name: bills1996_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1996_s_ts_idx;


--
-- Name: bills1996_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1996_sconres_ts_idx;


--
-- Name: bills1996_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1996_sjres_ts_idx;


--
-- Name: bills1996_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1996_sres_ts_idx;


--
-- Name: bills1996_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1996_statusat_idx;


--
-- Name: bills1997_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1997_billtype_idx;


--
-- Name: bills1997_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1997_hconres_ts_idx;


--
-- Name: bills1997_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1997_hjres_ts_idx;


--
-- Name: bills1997_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1997_hr_ts_idx;


--
-- Name: bills1997_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1997_hres_ts_idx;


--
-- Name: bills1997_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1997_pkey;


--
-- Name: bills1997_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1997_s_ts_idx;


--
-- Name: bills1997_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1997_sconres_ts_idx;


--
-- Name: bills1997_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1997_sjres_ts_idx;


--
-- Name: bills1997_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1997_sres_ts_idx;


--
-- Name: bills1997_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1997_statusat_idx;


--
-- Name: bills1998_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1998_billtype_idx;


--
-- Name: bills1998_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1998_hconres_ts_idx;


--
-- Name: bills1998_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1998_hjres_ts_idx;


--
-- Name: bills1998_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1998_hr_ts_idx;


--
-- Name: bills1998_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1998_hres_ts_idx;


--
-- Name: bills1998_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1998_pkey;


--
-- Name: bills1998_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1998_s_ts_idx;


--
-- Name: bills1998_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1998_sconres_ts_idx;


--
-- Name: bills1998_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1998_sjres_ts_idx;


--
-- Name: bills1998_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1998_sres_ts_idx;


--
-- Name: bills1998_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1998_statusat_idx;


--
-- Name: bills1999_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills1999_billtype_idx;


--
-- Name: bills1999_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills1999_hconres_ts_idx;


--
-- Name: bills1999_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills1999_hjres_ts_idx;


--
-- Name: bills1999_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills1999_hr_ts_idx;


--
-- Name: bills1999_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills1999_hres_ts_idx;


--
-- Name: bills1999_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills1999_pkey;


--
-- Name: bills1999_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills1999_s_ts_idx;


--
-- Name: bills1999_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills1999_sconres_ts_idx;


--
-- Name: bills1999_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills1999_sjres_ts_idx;


--
-- Name: bills1999_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills1999_sres_ts_idx;


--
-- Name: bills1999_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills1999_statusat_idx;


--
-- Name: bills2000_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2000_billtype_idx;


--
-- Name: bills2000_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2000_hconres_ts_idx;


--
-- Name: bills2000_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2000_hjres_ts_idx;


--
-- Name: bills2000_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2000_hr_ts_idx;


--
-- Name: bills2000_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2000_hres_ts_idx;


--
-- Name: bills2000_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2000_pkey;


--
-- Name: bills2000_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2000_s_ts_idx;


--
-- Name: bills2000_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2000_sconres_ts_idx;


--
-- Name: bills2000_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2000_sjres_ts_idx;


--
-- Name: bills2000_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2000_sres_ts_idx;


--
-- Name: bills2000_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2000_statusat_idx;


--
-- Name: bills2001_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2001_billtype_idx;


--
-- Name: bills2001_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2001_hconres_ts_idx;


--
-- Name: bills2001_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2001_hjres_ts_idx;


--
-- Name: bills2001_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2001_hr_ts_idx;


--
-- Name: bills2001_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2001_hres_ts_idx;


--
-- Name: bills2001_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2001_pkey;


--
-- Name: bills2001_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2001_s_ts_idx;


--
-- Name: bills2001_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2001_sconres_ts_idx;


--
-- Name: bills2001_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2001_sjres_ts_idx;


--
-- Name: bills2001_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2001_sres_ts_idx;


--
-- Name: bills2001_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2001_statusat_idx;


--
-- Name: bills2002_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2002_billtype_idx;


--
-- Name: bills2002_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2002_hconres_ts_idx;


--
-- Name: bills2002_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2002_hjres_ts_idx;


--
-- Name: bills2002_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2002_hr_ts_idx;


--
-- Name: bills2002_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2002_hres_ts_idx;


--
-- Name: bills2002_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2002_pkey;


--
-- Name: bills2002_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2002_s_ts_idx;


--
-- Name: bills2002_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2002_sconres_ts_idx;


--
-- Name: bills2002_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2002_sjres_ts_idx;


--
-- Name: bills2002_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2002_sres_ts_idx;


--
-- Name: bills2002_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2002_statusat_idx;


--
-- Name: bills2003_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2003_billtype_idx;


--
-- Name: bills2003_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2003_hconres_ts_idx;


--
-- Name: bills2003_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2003_hjres_ts_idx;


--
-- Name: bills2003_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2003_hr_ts_idx;


--
-- Name: bills2003_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2003_hres_ts_idx;


--
-- Name: bills2003_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2003_pkey;


--
-- Name: bills2003_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2003_s_ts_idx;


--
-- Name: bills2003_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2003_sconres_ts_idx;


--
-- Name: bills2003_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2003_sjres_ts_idx;


--
-- Name: bills2003_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2003_sres_ts_idx;


--
-- Name: bills2003_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2003_statusat_idx;


--
-- Name: bills2004_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2004_billtype_idx;


--
-- Name: bills2004_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2004_hconres_ts_idx;


--
-- Name: bills2004_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2004_hjres_ts_idx;


--
-- Name: bills2004_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2004_hr_ts_idx;


--
-- Name: bills2004_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2004_hres_ts_idx;


--
-- Name: bills2004_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2004_pkey;


--
-- Name: bills2004_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2004_s_ts_idx;


--
-- Name: bills2004_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2004_sconres_ts_idx;


--
-- Name: bills2004_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2004_sjres_ts_idx;


--
-- Name: bills2004_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2004_sres_ts_idx;


--
-- Name: bills2004_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2004_statusat_idx;


--
-- Name: bills2005_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2005_billtype_idx;


--
-- Name: bills2005_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2005_hconres_ts_idx;


--
-- Name: bills2005_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2005_hjres_ts_idx;


--
-- Name: bills2005_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2005_hr_ts_idx;


--
-- Name: bills2005_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2005_hres_ts_idx;


--
-- Name: bills2005_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2005_pkey;


--
-- Name: bills2005_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2005_s_ts_idx;


--
-- Name: bills2005_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2005_sconres_ts_idx;


--
-- Name: bills2005_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2005_sjres_ts_idx;


--
-- Name: bills2005_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2005_sres_ts_idx;


--
-- Name: bills2005_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2005_statusat_idx;


--
-- Name: bills2006_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2006_billtype_idx;


--
-- Name: bills2006_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2006_hconres_ts_idx;


--
-- Name: bills2006_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2006_hjres_ts_idx;


--
-- Name: bills2006_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2006_hr_ts_idx;


--
-- Name: bills2006_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2006_hres_ts_idx;


--
-- Name: bills2006_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2006_pkey;


--
-- Name: bills2006_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2006_s_ts_idx;


--
-- Name: bills2006_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2006_sconres_ts_idx;


--
-- Name: bills2006_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2006_sjres_ts_idx;


--
-- Name: bills2006_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2006_sres_ts_idx;


--
-- Name: bills2006_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2006_statusat_idx;


--
-- Name: bills2007_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2007_billtype_idx;


--
-- Name: bills2007_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2007_hconres_ts_idx;


--
-- Name: bills2007_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2007_hjres_ts_idx;


--
-- Name: bills2007_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2007_hr_ts_idx;


--
-- Name: bills2007_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2007_hres_ts_idx;


--
-- Name: bills2007_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2007_pkey;


--
-- Name: bills2007_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2007_s_ts_idx;


--
-- Name: bills2007_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2007_sconres_ts_idx;


--
-- Name: bills2007_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2007_sjres_ts_idx;


--
-- Name: bills2007_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2007_sres_ts_idx;


--
-- Name: bills2007_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2007_statusat_idx;


--
-- Name: bills2008_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2008_billtype_idx;


--
-- Name: bills2008_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2008_hconres_ts_idx;


--
-- Name: bills2008_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2008_hjres_ts_idx;


--
-- Name: bills2008_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2008_hr_ts_idx;


--
-- Name: bills2008_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2008_hres_ts_idx;


--
-- Name: bills2008_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2008_pkey;


--
-- Name: bills2008_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2008_s_ts_idx;


--
-- Name: bills2008_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2008_sconres_ts_idx;


--
-- Name: bills2008_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2008_sjres_ts_idx;


--
-- Name: bills2008_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2008_sres_ts_idx;


--
-- Name: bills2008_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2008_statusat_idx;


--
-- Name: bills2009_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2009_billtype_idx;


--
-- Name: bills2009_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2009_hconres_ts_idx;


--
-- Name: bills2009_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2009_hjres_ts_idx;


--
-- Name: bills2009_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2009_hr_ts_idx;


--
-- Name: bills2009_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2009_hres_ts_idx;


--
-- Name: bills2009_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2009_pkey;


--
-- Name: bills2009_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2009_s_ts_idx;


--
-- Name: bills2009_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2009_sconres_ts_idx;


--
-- Name: bills2009_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2009_sjres_ts_idx;


--
-- Name: bills2009_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2009_sres_ts_idx;


--
-- Name: bills2009_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2009_statusat_idx;


--
-- Name: bills2010_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2010_billtype_idx;


--
-- Name: bills2010_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2010_hconres_ts_idx;


--
-- Name: bills2010_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2010_hjres_ts_idx;


--
-- Name: bills2010_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2010_hr_ts_idx;


--
-- Name: bills2010_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2010_hres_ts_idx;


--
-- Name: bills2010_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2010_pkey;


--
-- Name: bills2010_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2010_s_ts_idx;


--
-- Name: bills2010_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2010_sconres_ts_idx;


--
-- Name: bills2010_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2010_sjres_ts_idx;


--
-- Name: bills2010_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2010_sres_ts_idx;


--
-- Name: bills2010_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2010_statusat_idx;


--
-- Name: bills2011_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2011_billtype_idx;


--
-- Name: bills2011_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2011_hconres_ts_idx;


--
-- Name: bills2011_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2011_hjres_ts_idx;


--
-- Name: bills2011_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2011_hr_ts_idx;


--
-- Name: bills2011_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2011_hres_ts_idx;


--
-- Name: bills2011_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2011_pkey;


--
-- Name: bills2011_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2011_s_ts_idx;


--
-- Name: bills2011_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2011_sconres_ts_idx;


--
-- Name: bills2011_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2011_sjres_ts_idx;


--
-- Name: bills2011_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2011_sres_ts_idx;


--
-- Name: bills2011_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2011_statusat_idx;


--
-- Name: bills2012_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2012_billtype_idx;


--
-- Name: bills2012_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2012_hconres_ts_idx;


--
-- Name: bills2012_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2012_hjres_ts_idx;


--
-- Name: bills2012_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2012_hr_ts_idx;


--
-- Name: bills2012_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2012_hres_ts_idx;


--
-- Name: bills2012_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2012_pkey;


--
-- Name: bills2012_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2012_s_ts_idx;


--
-- Name: bills2012_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2012_sconres_ts_idx;


--
-- Name: bills2012_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2012_sjres_ts_idx;


--
-- Name: bills2012_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2012_sres_ts_idx;


--
-- Name: bills2012_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2012_statusat_idx;


--
-- Name: bills2013_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2013_billtype_idx;


--
-- Name: bills2013_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2013_hconres_ts_idx;


--
-- Name: bills2013_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2013_hjres_ts_idx;


--
-- Name: bills2013_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2013_hr_ts_idx;


--
-- Name: bills2013_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2013_hres_ts_idx;


--
-- Name: bills2013_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2013_pkey;


--
-- Name: bills2013_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2013_s_ts_idx;


--
-- Name: bills2013_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2013_sconres_ts_idx;


--
-- Name: bills2013_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2013_sjres_ts_idx;


--
-- Name: bills2013_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2013_sres_ts_idx;


--
-- Name: bills2013_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2013_statusat_idx;


--
-- Name: bills2014_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2014_billtype_idx;


--
-- Name: bills2014_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2014_hconres_ts_idx;


--
-- Name: bills2014_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2014_hjres_ts_idx;


--
-- Name: bills2014_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2014_hr_ts_idx;


--
-- Name: bills2014_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2014_hres_ts_idx;


--
-- Name: bills2014_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2014_pkey;


--
-- Name: bills2014_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2014_s_ts_idx;


--
-- Name: bills2014_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2014_sconres_ts_idx;


--
-- Name: bills2014_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2014_sjres_ts_idx;


--
-- Name: bills2014_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2014_sres_ts_idx;


--
-- Name: bills2014_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2014_statusat_idx;


--
-- Name: bills2015_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2015_billtype_idx;


--
-- Name: bills2015_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2015_hconres_ts_idx;


--
-- Name: bills2015_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2015_hjres_ts_idx;


--
-- Name: bills2015_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2015_hr_ts_idx;


--
-- Name: bills2015_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2015_hres_ts_idx;


--
-- Name: bills2015_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2015_pkey;


--
-- Name: bills2015_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2015_s_ts_idx;


--
-- Name: bills2015_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2015_sconres_ts_idx;


--
-- Name: bills2015_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2015_sjres_ts_idx;


--
-- Name: bills2015_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2015_sres_ts_idx;


--
-- Name: bills2015_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2015_statusat_idx;


--
-- Name: bills2016_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2016_billtype_idx;


--
-- Name: bills2016_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2016_hconres_ts_idx;


--
-- Name: bills2016_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2016_hjres_ts_idx;


--
-- Name: bills2016_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2016_hr_ts_idx;


--
-- Name: bills2016_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2016_hres_ts_idx;


--
-- Name: bills2016_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2016_pkey;


--
-- Name: bills2016_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2016_s_ts_idx;


--
-- Name: bills2016_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2016_sconres_ts_idx;


--
-- Name: bills2016_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2016_sjres_ts_idx;


--
-- Name: bills2016_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2016_sres_ts_idx;


--
-- Name: bills2016_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2016_statusat_idx;


--
-- Name: bills2017_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2017_billtype_idx;


--
-- Name: bills2017_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2017_hconres_ts_idx;


--
-- Name: bills2017_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2017_hjres_ts_idx;


--
-- Name: bills2017_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2017_hr_ts_idx;


--
-- Name: bills2017_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2017_hres_ts_idx;


--
-- Name: bills2017_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2017_pkey;


--
-- Name: bills2017_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2017_s_ts_idx;


--
-- Name: bills2017_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2017_sconres_ts_idx;


--
-- Name: bills2017_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2017_sjres_ts_idx;


--
-- Name: bills2017_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2017_sres_ts_idx;


--
-- Name: bills2017_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2017_statusat_idx;


--
-- Name: bills2018_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2018_billtype_idx;


--
-- Name: bills2018_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2018_hconres_ts_idx;


--
-- Name: bills2018_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2018_hjres_ts_idx;


--
-- Name: bills2018_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2018_hr_ts_idx;


--
-- Name: bills2018_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2018_hres_ts_idx;


--
-- Name: bills2018_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2018_pkey;


--
-- Name: bills2018_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2018_s_ts_idx;


--
-- Name: bills2018_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2018_sconres_ts_idx;


--
-- Name: bills2018_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2018_sjres_ts_idx;


--
-- Name: bills2018_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2018_sres_ts_idx;


--
-- Name: bills2018_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2018_statusat_idx;


--
-- Name: bills2019_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2019_billtype_idx;


--
-- Name: bills2019_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2019_hconres_ts_idx;


--
-- Name: bills2019_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2019_hjres_ts_idx;


--
-- Name: bills2019_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2019_hr_ts_idx;


--
-- Name: bills2019_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2019_hres_ts_idx;


--
-- Name: bills2019_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2019_pkey;


--
-- Name: bills2019_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2019_s_ts_idx;


--
-- Name: bills2019_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2019_sconres_ts_idx;


--
-- Name: bills2019_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2019_sjres_ts_idx;


--
-- Name: bills2019_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2019_sres_ts_idx;


--
-- Name: bills2019_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2019_statusat_idx;


--
-- Name: bills2020_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2020_billtype_idx;


--
-- Name: bills2020_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2020_hconres_ts_idx;


--
-- Name: bills2020_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2020_hjres_ts_idx;


--
-- Name: bills2020_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2020_hr_ts_idx;


--
-- Name: bills2020_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2020_hres_ts_idx;


--
-- Name: bills2020_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2020_pkey;


--
-- Name: bills2020_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2020_s_ts_idx;


--
-- Name: bills2020_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2020_sconres_ts_idx;


--
-- Name: bills2020_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2020_sjres_ts_idx;


--
-- Name: bills2020_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2020_sres_ts_idx;


--
-- Name: bills2020_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2020_statusat_idx;


--
-- Name: bills2021_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2021_billtype_idx;


--
-- Name: bills2021_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2021_hconres_ts_idx;


--
-- Name: bills2021_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2021_hjres_ts_idx;


--
-- Name: bills2021_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2021_hr_ts_idx;


--
-- Name: bills2021_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2021_hres_ts_idx;


--
-- Name: bills2021_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2021_pkey;


--
-- Name: bills2021_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2021_s_ts_idx;


--
-- Name: bills2021_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2021_sconres_ts_idx;


--
-- Name: bills2021_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2021_sjres_ts_idx;


--
-- Name: bills2021_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2021_sres_ts_idx;


--
-- Name: bills2021_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2021_statusat_idx;


--
-- Name: bills2022_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2022_billtype_idx;


--
-- Name: bills2022_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2022_hconres_ts_idx;


--
-- Name: bills2022_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2022_hjres_ts_idx;


--
-- Name: bills2022_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2022_hr_ts_idx;


--
-- Name: bills2022_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2022_hres_ts_idx;


--
-- Name: bills2022_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2022_pkey;


--
-- Name: bills2022_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2022_s_ts_idx;


--
-- Name: bills2022_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2022_sconres_ts_idx;


--
-- Name: bills2022_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2022_sjres_ts_idx;


--
-- Name: bills2022_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2022_sres_ts_idx;


--
-- Name: bills2022_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2022_statusat_idx;


--
-- Name: bills2023_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2023_billtype_idx;


--
-- Name: bills2023_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2023_hconres_ts_idx;


--
-- Name: bills2023_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2023_hjres_ts_idx;


--
-- Name: bills2023_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2023_hr_ts_idx;


--
-- Name: bills2023_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2023_hres_ts_idx;


--
-- Name: bills2023_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2023_pkey;


--
-- Name: bills2023_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2023_s_ts_idx;


--
-- Name: bills2023_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2023_sconres_ts_idx;


--
-- Name: bills2023_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2023_sjres_ts_idx;


--
-- Name: bills2023_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2023_sres_ts_idx;


--
-- Name: bills2023_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2023_statusat_idx;


--
-- Name: bills2024_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2024_billtype_idx;


--
-- Name: bills2024_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2024_hconres_ts_idx;


--
-- Name: bills2024_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2024_hjres_ts_idx;


--
-- Name: bills2024_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2024_hr_ts_idx;


--
-- Name: bills2024_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2024_hres_ts_idx;


--
-- Name: bills2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2024_pkey;


--
-- Name: bills2024_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2024_s_ts_idx;


--
-- Name: bills2024_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2024_sconres_ts_idx;


--
-- Name: bills2024_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2024_sjres_ts_idx;


--
-- Name: bills2024_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2024_sres_ts_idx;


--
-- Name: bills2024_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2024_statusat_idx;


--
-- Name: bills2025_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2025_billtype_idx;


--
-- Name: bills2025_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2025_hconres_ts_idx;


--
-- Name: bills2025_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2025_hjres_ts_idx;


--
-- Name: bills2025_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2025_hr_ts_idx;


--
-- Name: bills2025_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2025_hres_ts_idx;


--
-- Name: bills2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2025_pkey;


--
-- Name: bills2025_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2025_s_ts_idx;


--
-- Name: bills2025_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2025_sconres_ts_idx;


--
-- Name: bills2025_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2025_sjres_ts_idx;


--
-- Name: bills2025_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2025_sres_ts_idx;


--
-- Name: bills2025_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2025_statusat_idx;


--
-- Name: bills2026_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2026_billtype_idx;


--
-- Name: bills2026_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2026_hconres_ts_idx;


--
-- Name: bills2026_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2026_hjres_ts_idx;


--
-- Name: bills2026_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2026_hr_ts_idx;


--
-- Name: bills2026_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2026_hres_ts_idx;


--
-- Name: bills2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2026_pkey;


--
-- Name: bills2026_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2026_s_ts_idx;


--
-- Name: bills2026_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2026_sconres_ts_idx;


--
-- Name: bills2026_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2026_sjres_ts_idx;


--
-- Name: bills2026_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2026_sres_ts_idx;


--
-- Name: bills2026_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2026_statusat_idx;


--
-- Name: bills2027_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2027_billtype_idx;


--
-- Name: bills2027_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2027_hconres_ts_idx;


--
-- Name: bills2027_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2027_hjres_ts_idx;


--
-- Name: bills2027_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2027_hr_ts_idx;


--
-- Name: bills2027_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2027_hres_ts_idx;


--
-- Name: bills2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2027_pkey;


--
-- Name: bills2027_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2027_s_ts_idx;


--
-- Name: bills2027_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2027_sconres_ts_idx;


--
-- Name: bills2027_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2027_sjres_ts_idx;


--
-- Name: bills2027_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2027_sres_ts_idx;


--
-- Name: bills2027_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2027_statusat_idx;


--
-- Name: bills2028_billtype_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_billtype_idx ATTACH PARTITION public.bills2028_billtype_idx;


--
-- Name: bills2028_hconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hconres_ts_idx ATTACH PARTITION public.bills2028_hconres_ts_idx;


--
-- Name: bills2028_hjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hjres_ts_idx ATTACH PARTITION public.bills2028_hjres_ts_idx;


--
-- Name: bills2028_hr_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hr_ts_idx ATTACH PARTITION public.bills2028_hr_ts_idx;


--
-- Name: bills2028_hres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.hres_ts_idx ATTACH PARTITION public.bills2028_hres_ts_idx;


--
-- Name: bills2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bill_pkey ATTACH PARTITION public.bills2028_pkey;


--
-- Name: bills2028_s_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.s_ts_idx ATTACH PARTITION public.bills2028_s_ts_idx;


--
-- Name: bills2028_sconres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sconres_ts_idx ATTACH PARTITION public.bills2028_sconres_ts_idx;


--
-- Name: bills2028_sjres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sjres_ts_idx ATTACH PARTITION public.bills2028_sjres_ts_idx;


--
-- Name: bills2028_sres_ts_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.sres_ts_idx ATTACH PARTITION public.bills2028_sres_ts_idx;


--
-- Name: bills2028_statusat_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.bills_statusat_idx ATTACH PARTITION public.bills2028_statusat_idx;


--
-- PostgreSQL database dump complete
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

CREATE INDEX on votes (votedate);
CREATE INDEX on votes (voteid);
CREATE INDEX on votes (chamber);
CREATE INDEX on votes (congress);
