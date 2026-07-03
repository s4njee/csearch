# Freya Postgres

## Schema + data

Schema comes from the `db-migrate` Job (`db/migrate.py` applying the
`db/migrations/` chain) — the same mechanism as netcup, no bootstrap SQL. Apply
by hand:

```bash
kubectl --context freya apply -k k8s/freya-db
kubectl --context freya -n default delete job db-migrate --ignore-not-found
kubectl --context freya apply -k k8s/freya-db   # re-runs db-migrate (idempotent)
```

freya carries **no data seed**. Prod row data (bills, votes, `zip_districts`, …)
arrives via **logical replication** from netcup — see
[`db/replication/`](../../db/replication/) for the one-time subscription setup.

## Backblaze B2 backups

`postgres-b2-backup` runs nightly at 07:17 UTC. It creates a custom-format
logical Postgres dump with `pg_dump -Fc`, stores it in a temporary `emptyDir`,
and uploads it to Backblaze B2 with restic. After each successful backup, it
runs `scripts/prune-b2-backups.sh` to keep 14 daily snapshots plus 8 weekly
snapshots and delete older snapshots.

Create the backup Secret before enabling or manually starting the CronJob:

```bash
kubectl --context freya create secret generic postgres-b2-backup \
  --from-literal=RESTIC_REPOSITORY='b2:<bucket-name>:csearch/freya/postgres' \
  --from-literal=RESTIC_PASSWORD='<restic-repository-password>' \
  --from-literal=B2_ACCOUNT_ID='<backblaze-key-id>' \
  --from-literal=B2_ACCOUNT_KEY='<backblaze-application-key>'
```

The B2 application key should be scoped to the backup bucket. The restic
password is independent from the B2 key; losing it means the backups cannot be
restored.

To trigger a backup immediately:

```bash
kubectl --context freya create job --from=cronjob/postgres-b2-backup postgres-b2-backup-manual-$(date +%s)
```

To prune older physical backup snapshots without creating a new backup, run the
same script from a machine with restic installed and these environment variables
set:

```bash
export RESTIC_REPOSITORY='b2:<bucket-name>:csearch/freya/postgres'
export RESTIC_PASSWORD='<restic-repository-password>'
export B2_ACCOUNT_ID='<backblaze-key-id>'
export B2_ACCOUNT_KEY='<backblaze-application-key>'
export RESTIC_KEEP_LAST=14
export RESTIC_KEEP_WEEKLY=8
export RESTIC_CLUSTER_TAG=freya
export RESTIC_BACKUP_TAG=logical

sh k8s/freya-db/scripts/prune-b2-backups.sh
```

To restore, recover the wanted `csearch-freya-*.dump` file with restic and use
`pg_restore` against a fresh database. See `docs/RESTORE.md` for the full
runbook.
