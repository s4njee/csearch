# Freya Postgres

## Backblaze B2 backups

`postgres-b2-backup` runs weekly on Sunday at 07:17 UTC. It creates a native
Postgres physical base backup with `pg_basebackup`, stores it in a temporary
`emptyDir`, and uploads it to Backblaze B2 with restic. After each successful
backup, it runs `scripts/prune-b2-backups.sh` to keep the latest 8 physical
backup snapshots and delete older snapshots.

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
export RESTIC_KEEP_LAST=8

sh k8s/freya-db/scripts/prune-b2-backups.sh
```

To restore, recover the wanted `csearch-basebackup-*` directory with restic,
stop Postgres, replace the data directory with the restored base backup
contents, and start Postgres against that restored data directory.
