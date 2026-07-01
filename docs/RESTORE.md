# Database Backup and Restore

Netcup and freya Postgres backups are nightly custom-format logical dumps
(`pg_dump -Fc`) uploaded to Backblaze B2 with restic by the
`postgres-b2-backup` CronJob.

## Create backup credentials

The repo must not contain plaintext backup credentials. Create the Secret in
freya directly:

```bash
kubectl --context freya create secret generic postgres-b2-backup \
  --from-literal=RESTIC_REPOSITORY='b2:<bucket-name>:csearch/freya/postgres' \
  --from-literal=RESTIC_PASSWORD='<restic-repository-password>' \
  --from-literal=B2_ACCOUNT_ID='<backblaze-key-id>' \
  --from-literal=B2_ACCOUNT_KEY='<backblaze-application-key>'
```

For netcup, seal the same Secret before committing it:

```bash
kubectl --context netcup create secret generic postgres-b2-backup \
  --from-literal=RESTIC_REPOSITORY='b2:<bucket-name>:csearch/netcup/postgres' \
  --from-literal=RESTIC_PASSWORD='<restic-repository-password>' \
  --from-literal=B2_ACCOUNT_ID='<backblaze-key-id>' \
  --from-literal=B2_ACCOUNT_KEY='<backblaze-application-key>' \
  --dry-run=client -o yaml \
  | kubeseal --context netcup -o yaml \
  > k8s/netcup-db/postgres-b2-backup-sealedsecret.yaml
```

After creating the sealed secret, add it to `k8s/netcup-db/kustomization.yaml`
under `resources`.

## Trigger a backup

```bash
kubectl --context netcup create job --from=cronjob/postgres-b2-backup postgres-b2-backup-manual-$(date +%s)
kubectl --context netcup logs -f job/<job-name> -c restic
```

## Restore test

Install `restic`, set the backup credentials locally, and restore a dump:

```bash
export RESTIC_REPOSITORY='b2:<bucket-name>:csearch/netcup/postgres'
export RESTIC_PASSWORD='<restic-repository-password>'
export B2_ACCOUNT_ID='<backblaze-key-id>'
export B2_ACCOUNT_KEY='<backblaze-application-key>'

mkdir -p /tmp/csearch-restore
restic snapshots --tag postgres --tag netcup --tag logical
restic restore latest --target /tmp/csearch-restore --tag postgres --tag netcup --tag logical
dump_file="$(find /tmp/csearch-restore -type f -name 'csearch-netcup-*.dump' | sort | tail -n 1)"
```

Restore into a scratch Postgres:

```bash
docker run --rm --name csearch-restore-pg \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=csearch_restore \
  -p 55432:5432 \
  -d pgvector/pgvector:pg18

until PGPASSWORD=postgres pg_isready -h localhost -p 55432 -U postgres -d csearch_restore; do
  sleep 1
done

PGPASSWORD=postgres pg_restore \
  --host localhost \
  --port 55432 \
  --username postgres \
  --dbname csearch_restore \
  --clean --if-exists --no-owner \
  "$dump_file"
```

Run restore smoke checks without loading fixtures or changing restored data:

```bash
PGPASSWORD=postgres psql \
  --host localhost \
  --port 55432 \
  --username postgres \
  --dbname csearch_restore \
  --set ON_ERROR_STOP=1 <<'SQL'
SELECT extname FROM pg_extension WHERE extname = 'vector';
SELECT count(*) AS bills FROM public.bills;
SELECT count(*) AS votes FROM public.votes;
SELECT count(*) AS bill_embeddings FROM nlp.bill_embeddings;
SELECT started_at, status FROM ops.scraper_runs ORDER BY started_at DESC LIMIT 1;
SELECT started_at, status FROM nlp.ingest_runs ORDER BY started_at DESC LIMIT 1;
SQL
```

Clean up:

```bash
docker rm -f csearch-restore-pg
rm -rf /tmp/csearch-restore
```
