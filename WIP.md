# CSearch WIP

This document is the active working view of the project. It is derived from:

- [`TODO.md`](./TODO.md)
- the current logging and observability implementation already present in the repo

It is intentionally narrower than `TODO.md`. The goal is to answer:

1. What is already done?
2. What is actively in progress?
3. What should we do next?

## Current Focus

The current highest-value workstream is:

1. finish the logging and observability rollout
2. close the scraper reliability gaps that logging has surfaced
3. improve developer ergonomics around local setup and operations

## Status Summary

### Logging and observability

Status: `partially shipped`

What is already in place:

- API JSON logging via Fastify/Pino in `backend/api/server.js`
- request completion logging in `backend/api/app.js`
- request-scoped error logging in `backend/api/app.js`
- search logging in `backend/api/routes/searchRoute.js`
- admin cache-reset audit logging in `backend/api/routes/adminRoute.js`
- slow explore query logging in `backend/api/routes/exploreRoute.js`
- scraper JSON logging via `log/slog` in `backend/scraper/main.go`
- structured scraper run summary logging in `backend/scraper/main.go`
- per-bill and per-vote ingest logging in:
  - `backend/scraper/bills.go`
  - `backend/scraper/votes.go`
- Python subprocess output re-emitted as structured logs in `backend/scraper/runtime.go`
- shared Loki, Grafana, and Fluent Bit stack now lives in the external `k8s_study/logging` module
- CSearch-specific dashboard assets now live in:
  - `k8s/logging/README.md`
  - `k8s/logging/dashboards/csearch-api-loki.json`
  - `k8s/logging/dashboards/csearch-scraper-loki.json`

What is still missing:

- validation that the logs are easy to query with `kubectl logs` and `jq`
- validation of the shared stack’s Loki label conventions in the live cluster
- CronJob failure alerting
- import and verification of the new dashboards in the shared Grafana instance

### Scraper reliability

Status: `not started enough`

The scraper is much more observable than before, but the core reliability concerns from `TODO.md` still remain:

- network retries are still limited
- partial ingest recovery is still weak
- malformed input validation before insert is still incomplete
- bill parser coverage is still thin

### Developer experience

Status: `moving`

Recent progress:

- repo documentation and onboarding docs were substantially improved
- tracked local env secret material was removed from the current branch state

Still open:

- add a local `.env.example`
- add a `Makefile`
- pin tool versions
- consolidate the most common operational commands

## Logging Workstream

## Goal

Make the platform easy to operate with lightweight structured logs before adding heavier monitoring systems.

## Completed

### API logging foundation

Completed items:

- structured Pino logger configuration
- redaction for authorization headers
- per-request completion logs with latency and cache status
- request-scoped error logs
- route-level business logs for search, cache clears, and slow explore queries

Primary files:

- `backend/api/server.js`
- `backend/api/app.js`
- `backend/api/routes/searchRoute.js`
- `backend/api/routes/adminRoute.js`
- `backend/api/routes/exploreRoute.js`

### Scraper logging foundation

Completed items:

- default `slog` JSON logger setup
- run start and end summary logs
- per-bill ingest logs
- per-vote ingest logs
- structured re-publication of Python subprocess output

Primary files:

- `backend/scraper/main.go`
- `backend/scraper/bills.go`
- `backend/scraper/votes.go`
- `backend/scraper/runtime.go`

### Shared logging stack

Completed items:

- shared Loki, Grafana, and Fluent Bit deployment moved out of this repo
- CSearch keeps only app-specific dashboards, queries, and log-shape documentation

Primary files:

- `deploy.sh`
- `k8s/logging/README.md`
- `k8s/logging/dashboards/csearch-api-loki.json`
- `k8s/logging/dashboards/csearch-scraper-loki.json`

## In Progress

### 1. Operational verification

We have logging code, but we still need to prove the logs are useful in real cluster workflows.

Open tasks:

- verify API logs are parseable with `kubectl logs ... | jq .`
- verify scraper summary logs can be filtered reliably
- verify the `X-Cache` field shows up consistently on cached routes
- verify the shared Fluent Bit to Loki pipeline produces the expected output shape

Definition of done:

- there is a short set of verified commands the team can use during incidents
- the output is readable and consistent for API and scraper logs

### 2. Failure visibility for scheduled jobs

The scraper is a CronJob, so silent failure is one of the highest-risk platform issues.

Open tasks:

- add alerting or explicit failure detection for `BackoffLimitExceeded`
- define how failures should be routed
- capture “successful run but zero useful work” as a detectable condition

Definition of done:

- operators can tell the difference between:
  - successful run
  - failed run
  - suspicious run with zero processed items

## Next Up

### Priority 1

- verify cluster log queries and document them
- add CronJob failure alerting
- define log sink naming conventions or equivalent saved queries

### Priority 2

- add bill parser tests for both XML schema paths
- add partial-ingest behavior so one bad file does not fail an entire run
- add retry logic around source downloads

### Priority 3

- add a local `.env.example`
- add a `Makefile` with common commands
- pin Node and Go versions for contributors

## Suggested Execution Plan

### Phase A: Close the logging rollout

1. Deploy current logging changes to a non-production-safe environment if needed
2. Run and record the `kubectl logs` verification commands
3. Confirm API and scraper logs are queryable with `jq`
4. Confirm Fluent Bit output shape
5. Add operational notes back into docs if anything is missing

### Phase B: Add failure detection

1. Detect failed scraper jobs
2. Detect empty or suspicious scraper runs
3. Decide and implement alert routing

### Phase C: Improve scraper resilience

1. Add retry logic
2. Add partial-ingest behavior
3. Add parser validation and tests

## Recommended Commands To Verify Logging

These are the first commands worth standardizing:

```bash
kubectl logs -l app.kubernetes.io/name=csearch-api --since=1h | jq .
kubectl logs job/<job-name> | jq .
kubectl logs -l app.kubernetes.io/name=csearch-updater --since=24h | jq 'select(.msg == "scraper run complete")'
kubectl logs -l app.kubernetes.io/name=csearch-api --since=1h | jq 'select(.msg == "request completed")'
```

Note:

- the label selectors above reflect the current manifests in `k8s/`
- if operators use different selectors in practice, this file should be updated to match reality

## Related TODO Items Worth Pulling Forward

These are not strictly “logging” tasks, but they benefit directly from the new visibility:

- Scraper reliability
  - retry logic for failed downloads
  - graceful partial ingest
  - bill parsing tests
  - integration coverage for XML to DB flow
- Security hardening
  - ensure secrets never leak into logs
  - keep audit logging for admin endpoints
- Developer experience
  - local `.env.example`
  - `Makefile`
  - pinned tool versions

## Explicitly Deferred

These are still good ideas, but they should not block the current workstream:

- Prometheus and Grafana as the primary observability path
- OpenTelemetry or distributed tracing
- self-hosted log database infrastructure
- Redis migration purely for observability reasons

## Open Questions

- What is the preferred destination for scraper-failure alerts?
- Do we want one shared saved-query playbook for logs, or just CLI-first commands?
- Should suspicious scraper runs be based on:
  - zero processed items
  - spike in failed items
  - runtime anomaly
  - all three

## Maintenance Note

When work from this file is completed, update both:

- this file, to reflect current execution status
- [`TODO.md`](./TODO.md), so the broader backlog does not drift away from reality
