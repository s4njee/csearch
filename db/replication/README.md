# freya ← netcup mirror via logical replication

The end-goal for making freya a real prod mirror (BACKLOG E3): freya stays a
**writable** cluster, runs the **same migrations** as netcup for its schema, and
pulls prod **row data** continuously over Postgres **logical replication**.

```
 netcup (prod, publisher)                 freya (dev, subscriber)
 ┌────────────────────────┐   logical     ┌────────────────────────┐
 │ PUBLICATION csearch_pub │ ───stream──▶ │ SUBSCRIPTION csearch_sub │
 │ wal_level = logical     │               │ same schema (migrations) │
 └────────────────────────┘               └────────────────────────┘
```

Why logical (not physical streaming): a physical standby is **read-only**, which
would kill freya's job as a place to test writes before prod. Logical keeps
freya writable and only mirrors the subscribed tables. The tradeoff is that DDL
does **not** replicate — which is exactly why the `db-migrate` Job runs the same
`db/migrations/` chain on both clusters so the schemas already match.

## One-time setup

### 0. Network path (freya → netcup:5432)
The subscriber opens the connection, so freya must be able to reach netcup's
Postgres. netcup is a public VPS; **do not expose 5432 to the internet.** Put the
two nodes on a private overlay (WireGuard or Tailscale) and use that address in
the subscription CONNINFO below. The default image `pg_hba.conf` already permits
password (`scram-sha-256`) host connections, so no pg_hba edit is needed on
netcup for a normal (logical) connection.

### 1. Publisher (netcup) — once
Confirm `wal_level` flipped after the StatefulSet rolled onto the new args
(**this restarts prod Postgres**):
```bash
kubectl --context netcup exec -it statefulset/postgres -- psql -U postgres -d csearch -c 'SHOW wal_level;'
# must print: logical
```
Then apply the publication:
```bash
kubectl --context netcup exec -i statefulset/postgres -- \
  psql -U postgres -d csearch -v ON_ERROR_STOP=1 < db/replication/publisher.sql
```

### 2. Subscriber (freya) — once, on an EMPTY schema
Bring freya's DB up under the new mechanism first so the schema matches and the
tables are empty (the initial copy fills them):
```bash
kubectl --context freya apply -k k8s/freya-db
kubectl --context freya -n default delete job db-migrate --ignore-not-found
kubectl --context freya apply -k k8s/freya-db          # runs db-migrate → schema
```
Then create the subscription (fill in the private host + a real password; prefer
a dedicated replication role over `postgres`):
```sql
CREATE SUBSCRIPTION csearch_sub
  CONNECTION 'host=<netcup-private-ip> port=5432 dbname=csearch user=postgres password=<pw> sslmode=require'
  PUBLICATION csearch_pub
  WITH (copy_data = true, streaming = on);
```
`copy_data = true` snapshots all current rows, then streams changes live.

> If freya already holds test rows, `TRUNCATE` the target tables first (or drop
> the PVC and re-migrate) — the initial copy will error on primary-key clashes.

## Operating notes
- **Check health:** `SELECT * FROM pg_stat_subscription;` on freya;
  `SELECT * FROM pg_replication_slots;` on netcup (slot must stay `active` — an
  inactive slot pins WAL and can fill netcup's disk).
- **Sequences are not replicated.** csearch keys are natural (billtype/number/
  congress), so this is mostly moot; reset any serial sequences on freya if used.
- **New tables** from future migrations: `FOR ALL TABLES` auto-publishes them,
  but the subscriber only picks them up on
  `ALTER SUBSCRIPTION csearch_sub REFRESH PUBLICATION;` (run after migrating both
  sides).
- **Teardown:** `DROP SUBSCRIPTION csearch_sub;` on freya (drops the remote slot
  too), then `DROP PUBLICATION csearch_pub;` on netcup.
