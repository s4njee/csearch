-- Publisher setup — run ONCE on netcup (prod) as a superuser.
--
-- Prereq: the StatefulSet already sets wal_level=logical, max_wal_senders and
-- max_replication_slots (k8s/netcup-db/postgres-statefulset.yaml). Confirm with
--   SHOW wal_level;   -- must print: logical
-- If it prints "replica", the pod hasn't restarted onto the new args yet.

-- 1. Every published table needs a replica identity so UPDATE/DELETE can
--    replicate. Tables with a PRIMARY KEY are fine as-is; this backstops any
--    table that lacks one by promoting it to REPLICA IDENTITY FULL. Review the
--    output before relying on it — FULL makes UPDATEs log the whole old row.
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.oid::regclass AS tbl
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r', 'p')                 -- ordinary + partitioned
          AND n.nspname IN ('public', 'nlp', 'audit', 'ops')
          AND c.relreplident = 'd'                     -- default (= PK)
          AND NOT EXISTS (
              SELECT 1 FROM pg_index i
              WHERE i.indrelid = c.oid AND i.indisprimary
          )
    LOOP
        RAISE NOTICE 'No PK on %, setting REPLICA IDENTITY FULL', r.tbl;
        EXECUTE format('ALTER TABLE %s REPLICA IDENTITY FULL', r.tbl);
    END LOOP;
END $$;

-- 2. Publish everything so freya is a true mirror. FOR ALL TABLES also picks up
--    tables added by future migrations automatically. publish_via_partition_root
--    replicates the partitioned `bills` as its root table, which is robust even
--    if partition layouts ever differ between clusters.
DROP PUBLICATION IF EXISTS csearch_pub;
CREATE PUBLICATION csearch_pub
    FOR ALL TABLES
    WITH (publish_via_partition_root = true);

-- 3. Inspect:
--   SELECT * FROM pg_publication;
--   SELECT * FROM pg_publication_tables WHERE pubname = 'csearch_pub';
