# CSearch Logging Assets

This directory now holds CSearch-specific logging assets for a shared Loki and Grafana stack.

The logging infrastructure itself is no longer deployed from this repo. The source of truth for the shared cluster logging stack is the generic `logging/` module in the separate `k8s_study` repo.

Use this directory for:

- CSearch-specific Grafana dashboards
- saved LogQL queries and operator notes
- assumptions about the structured log fields emitted by the API and scraper

## Prerequisite

Install the shared logging stack first from the `k8s_study` repo:

- Loki
- Fluent Bit
- the Grafana instance from `kube-prometheus-stack`

This repo assumes that stack is already available and that the `monitoring-stack` Grafana instance has a Loki datasource provisioned.

## CSearch log assumptions

The dashboards in `dashboards/` assume Fluent Bit emits these Loki labels:

- `namespace`
- `pod`
- `container`
- `app`

For CSearch, the important app values are:

- `csearch-api`
- `csearch-updater`

The dashboards also assume the application log body remains structured JSON.

### API log lines used by the dashboards

- `msg="request completed"` with:
  - `route`
  - `responseTime`
  - `statusCode`
  - `cache`
- `msg="search executed"` with:
  - `query`
  - `table`
  - `filter`
  - `resultCount`

### Scraper log lines used by the dashboards

- `msg="scraper run complete"` with:
  - `bills_processed`
  - `bills_skipped`
  - `bills_failed`
  - `votes_processed`
  - `votes_skipped`
  - `votes_failed`
  - `duration_s`

## Import or provision the dashboards

1. Open Grafana from the shared `kube-prometheus-stack` install.
2. Go to Dashboards, then Import.
3. Import:
   - `dashboards/csearch-api-loki.json`
   - `dashboards/csearch-scraper-loki.json`
4. Select the existing `Loki` datasource.

If you provision these dashboards from Kubernetes `ConfigMap`s instead of importing them by hand:

- keep the `grafana_dashboard=1` label on each `ConfigMap`
- keep the dashboard JSON pinned to the explicit datasource name `Loki`
- do not use `${DS_LOKI}` placeholders, because those are import-time inputs and will not resolve reliably for sidecar-provisioned dashboards

If you are accessing Grafana locally, the expected port-forward is:

```bash
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
```

## Useful LogQL queries

API request volume by route:

```logql
sum by (route) (
  count_over_time({app="csearch-api"} | json | msg="request completed" [5m])
)
```

API p95 latency:

```logql
quantile_over_time(
  0.95,
  {app="csearch-api"} | json | msg="request completed" | unwrap responseTime [5m]
)
```

API cache hit rate:

```logql
100 *
sum(count_over_time({app="csearch-api"} | json | msg="request completed" | cache="HIT" [5m]))
/
sum(count_over_time({app="csearch-api"} | json | msg="request completed" [5m]))
```

Scraper run summaries:

```logql
{app="csearch-updater"} | json | msg="scraper run complete"
```

Scraper duration trend:

```logql
avg_over_time(
  {app="csearch-updater"} | json | msg="scraper run complete" | unwrap duration_s [24h]
)
```
