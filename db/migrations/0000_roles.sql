-- Roles required by later migrations.
--
-- The public schema is owned by the `csearch` role (see 0001). On a managed
-- cluster that role already exists; on a clean Postgres (CI, local Docker) it
-- does not, so create it idempotently here. NOLOGIN: it is an ownership role,
-- not a connection role.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'csearch') THEN
        CREATE ROLE csearch NOLOGIN;
    END IF;
END
$$;

-- PostgreSQL 15+ no longer grants CREATE on the public schema to non-owners,
-- so the csearch-owned bootstrap in 0001 needs this explicitly. Idempotent and
-- a no-op on managed clusters where csearch already owns its objects.
GRANT USAGE, CREATE ON SCHEMA public TO csearch;

-- The audit migration (0004) creates the `audit` schema while running as
-- csearch, which requires CREATE on the current database.
DO $$
BEGIN
    EXECUTE format('GRANT CREATE ON DATABASE %I TO csearch', current_database());
END
$$;
