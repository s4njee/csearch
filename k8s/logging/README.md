# CSearch Logging

This directory contains the logging assets that are actively used by the repo-owned deploy path.

The default model is:

1. Traefik writes structured JSON access logs to stdout
2. Fluent Bit tails Kubernetes container logs
3. Fluent Bit filters to CSearch workloads
4. Fluent Bit ships those records either:
   - to the tiny in-cluster HTTP collector, or
   - directly to S3

Optional Grafana and Loki dashboards are also stored here, but they are not the default deploy path from this repo.

## What This Directory Owns

| File or directory | Purpose |
| --- | --- |
| `fluent-bit-config.yaml` | Fluent Bit config for HTTP shipping |
| `fluent-bit-config-s3.yaml` | Fluent Bit config for ingress access logs to S3 |
| `fluent-bit-daemonset.yaml` | Fluent Bit DaemonSet |
| `fluent-bit-rbac.yaml` | RBAC for the DaemonSet |
| `collector-deployment.yaml` | Tiny log collector deployment |
| `collector-service.yaml` | Tiny log collector service |
| `dashboards/` | Optional Grafana dashboards for API logs, plus scraper-oriented examples |

## Deploy Modes

### Default: tiny in-cluster collector

`deploy.sh` uses this path when `ENABLE_TINY_LOG_COLLECTOR=true`.

Behavior:

- deploys `csearch-log-collector`
- renders `fluent-bit-config.yaml`
- points Fluent Bit at `csearch-log-collector:8080/ingest`
- writes newline-delimited JSON files to the host path configured by `LOG_COLLECTOR_HOSTPATH`

Default output location:

- `/root/logs/csearch/csearch/YYYY-MM-DD.ndjson`

### Direct S3 output

`deploy.sh` prefers this path when `LOG_S3_BUCKET` is set.

Behavior:

- renders `fluent-bit-config-s3.yaml`
- configures Fluent Bit's native `s3` output
- optionally creates the `csearch-fluent-bit-aws` secret when static AWS credentials are provided
- collects Traefik ingress access logs
- writes plain JSON objects in a flat `/csearch/ingress/` prefix

Important detail:

- the S3 path is the primary shipping path in this mode
- the tiny collector can still exist, but the DaemonSet will use the S3 config

### Fallback generic HTTP shipping

If `LOG_S3_BUCKET` is unset and `LOG_SHIP_HTTP_HOST` is set, `deploy.sh` renders the HTTP shipping config with those explicit destination settings.

## What Fluent Bit Ships

The current config intentionally stays narrow:

- it tails `/var/log/containers/*.log`
- it enriches records with Kubernetes metadata
- it only keeps workloads whose `app.kubernetes.io/name` is `traefik`
- it ships only Traefik access logs with a `ClientAddr`
- the tiny collector remains available for other shipping paths

It does not read application files directly from `backend/scraper/congress/data` or other host paths.

## Environment Variables

These variables control the logging deploy path:

| Variable | Meaning |
| --- | --- |
| `ENABLE_TINY_LOG_COLLECTOR` | enables the tiny collector path, defaults to `true` in `.env.prod.example` |
| `LOG_COLLECTOR_HOSTPATH` | host path used by the tiny collector, defaults to `/root/logs` |
| `LOG_S3_BUCKET` | enables direct S3 output when set |
| `LOG_S3_REGION` | S3 region for Fluent Bit |
| `LOG_S3_TOTAL_FILE_SIZE` | target file size before upload |
| `LOG_S3_UPLOAD_TIMEOUT` | upload timeout for Fluent Bit's S3 output |
| `LOG_S3_USE_PUT_OBJECT` | Fluent Bit S3 output toggle |
| `LOG_S3_STORE_DIR_LIMIT_SIZE` | local Fluent Bit buffer limit for S3 uploads |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` | optional static AWS credentials for Fluent Bit |
| `LOG_SHIP_HTTP_HOST` / `LOG_SHIP_HTTP_PORT` / `LOG_SHIP_HTTP_URI` | fallback HTTP ship destination |
| `LOG_SHIP_HTTP_TLS` / `LOG_SHIP_HTTP_TLS_VERIFY` | TLS options for the HTTP shipper |
| `CLUSTER_NAME` | record routing label used in rendered config |

## Useful Commands

Check the DaemonSet:

```bash
kubectl get daemonset csearch-fluent-bit
kubectl rollout status daemonset/csearch-fluent-bit
```

Check the tiny collector:

```bash
kubectl get deployment csearch-log-collector
kubectl logs deployment/csearch-log-collector
```

Inspect API and scraper logs directly before collection:

```bash
kubectl logs -l app.kubernetes.io/name=csearch-api --since=1h | jq .
kubectl logs -l app.kubernetes.io/name=csearch-updater --since=24h | jq 'select(.msg == "scraper run complete")'
```

## Optional Grafana Dashboards

The dashboards in `dashboards/` are useful if you already have Grafana and Loki somewhere else.

They assume:

- a datasource named `Loki`
- labels such as `namespace`, `pod`, `container`, and `app`
- JSON log bodies from the API and scraper, if you wire a shipper that includes scraper logs

Important detail:

- this repo does not currently deploy Grafana or Loki for you
- treat the dashboards as optional assets, not as the primary logging path
