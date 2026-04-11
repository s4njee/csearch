# CSearch — High-Impact Improvements

## 1. Logging & Observability

A lightweight, production-grade logging system using tools already in the stack (Pino for Node, `log/slog` for Go), shipping JSON to stdout for K8s collection.

### Phase 1: Fastify API — Structured Request Logging

Pino is already bundled with Fastify (`pino@^8.8.0` in package.json). The server already has `logger: true` in `server.js`, but no request-level detail is captured.

**1.1 Configure Pino with useful defaults in the Fastify startup path**
- [x] Replace `logger: true` with a Pino config object:
  ```js
  const app = Fastify({
    logger: {
      level: process.env.LOG_LEVEL || 'info',
      serializers: {
        req(req) {
          return { method: req.method, url: req.url, ip: req.ip, reqId: req.id }
        },
        res(res) {
          return { statusCode: res.statusCode }
        }
      },
      // Redact sensitive headers so SECRET_KEY can't leak
      redact: ['req.headers.authorization']
    }
  })
  ```
- [x] Set `LOG_LEVEL=info` in production env, `debug` for local/dev env

**1.2 Add `onResponse` hook in `app.js` for per-request log lines**
- [x] Add a hook after the cors/compress registration:
  ```js
  fastify.addHook('onResponse', (request, reply, done) => {
    request.log.info({
      responseTime: reply.elapsedTime,
      statusCode: reply.statusCode,
      cache: reply.getHeader('X-Cache') || 'NONE',
      route: request.routeOptions?.url || request.url,
    }, 'request completed')
    done()
  })
  ```
  This gives one structured JSON line per request with latency + cache hit/miss.

**1.3 Add contextual logging to route handlers**
- [x] In `searchRoute.js` — log search queries for analytics:
  ```js
  request.log.info({ query: searchQuery, table, filter, resultCount: results.length }, 'search executed')
  ```
- [x] In `adminRoute.js` — log cache clears (audit trail):
  ```js
  request.log.warn({ action: 'cache_clear', ip: request.ip }, 'admin cache reset')
  ```
- [x] In `exploreRoute.js` — log slow queries (>500ms):
  ```js
  if (reply.elapsedTime > 500) {
    request.log.warn({ queryId, responseTime: reply.elapsedTime }, 'slow explore query')
  }
  ```

**1.4 Add error context to catch blocks**
- [x] Add request-scoped error logging so route failures include route/status context instead of only the default Fastify 500 handler

### Phase 2: Go Scraper — Replace fmt/log with `log/slog`

The scraper currently uses `fmt.Println` for progress and `log.Fatal`/`log.Printf` for errors. `log/slog` is in the Go stdlib since 1.21 (bump `go.mod` from 1.19 → 1.21+).

**2.1 Initialize a JSON logger in `main.go`**
- [x] Add at top of `main()`:
  ```go
  logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
      Level: slog.LevelInfo,
  }))
  slog.SetDefault(logger)
  ```
- [x] Replace all `log.Fatalf(...)` calls with `slog.Error(...); os.Exit(1)` to get structured output even on fatal errors
- [x] Replace `log.Printf(...)` with `slog.Info(...)` or `slog.Warn(...)`

**2.2 Add per-bill and per-vote structured logging in `bills.go` / `votes.go`**
- [x] Log each successfully ingested bill:
  ```go
  slog.Info("bill ingested",
      "congress", congress,
      "billtype", billType,
      "billnumber", billNumber,
      "actions", len(parsed.Actions),
      "cosponsors", len(parsed.Cosponsors),
  )
  ```
- [x] Log skipped (unchanged hash) files at `debug` level:
  ```go
  slog.Debug("bill unchanged, skipping", "path", filePath)
  ```
- [x] Log parse failures as warnings (not fatals) to support partial ingest:
  ```go
  slog.Warn("bill parse failed", "path", filePath, "err", err)
  ```

**2.3 Emit a run summary at the end of `main()`**
- [x] Track counters through the ingest pipeline and log a single summary line:
  ```go
  slog.Info("scraper run complete",
      "bills_processed", stats.BillsProcessed,
      "bills_skipped", stats.BillsSkipped,
      "bills_failed", stats.BillsFailed,
      "votes_processed", stats.VotesProcessed,
      "votes_skipped", stats.VotesSkipped,
      "votes_failed", stats.VotesFailed,
      "duration_s", time.Since(startTime).Seconds(),
  )
  ```
  This single line is enough to build a CronJob health dashboard.

**2.4 Tag Python subprocess output**
- [x] In `runtime.go` `streamOutput()`, prefix Python lines with a slog entry so they're parseable:
  ```go
  slog.Info("python", "output", scanner.Text())
  ```

### Phase 3: Log Collection in K8s

No new infrastructure needed — K8s already captures stdout/stderr from all pods.

**3.1 Verify JSON output works with `kubectl logs`**
- [ ] After deploying the above changes, verify logs are parseable:
  ```bash
  kubectl logs -l app=csearch-api --since=1h | head -5 | jq .
  kubectl logs -l app=csearch-updater --since=24h | jq 'select(.msg == "scraper run complete")'
  ```

**3.2 Shared log shipping**
- [x] Add repo-owned Fluent Bit manifests and the tiny collector path under `k8s/logging/`
- [x] Keep CSearch-specific logging assets in `k8s/logging/`
- [x] Add CSearch Grafana dashboards for API and scraper log lines

**3.3 Set up CronJob failure alerting**
- [ ] Add a K8s Event watch or Fluent Bit filter for `reason=BackoffLimitExceeded` on the `csearch-updater` CronJob
- [ ] Route to Slack/PagerDuty/email — the scraper failing silently is the highest-risk gap today

### Phase 4: Operational Dashboards (when log sink is in place)

**4.1 API dashboard — build from Pino log lines**
- [x] Request rate by route (from `route` field)
- [x] p50/p95/p99 latency (from `responseTime` field)
- [x] Cache hit rate (from `cache` field: count HIT vs MISS)
- [x] Error rate by status code (from `statusCode` field)
- [x] Top search queries (from search log lines)

**4.2 Scraper dashboard — build from slog summary lines**
- [x] Bills/votes processed per run (from `scraper run complete` lines)
- [x] Failure rate trend (from `bills_failed` / `votes_failed` counters)
- [x] Run duration trend (from `duration_s` field)
- [x] Alert-oriented zero-processed run panel for follow-up alerting

### What NOT to do (keep it lightweight)

- **Don't add Prometheus yet** — structured logs are sufficient for the current scale; Prometheus adds operational overhead (scrape config, storage, Grafana). Revisit when you need real-time alerting on sub-minute latency spikes.
- **Don't add request tracing (Jaeger/OpenTelemetry)** — overkill for a 2-replica API with a single DB. The `reqId` in Pino logs provides enough correlation.
- **Don't add a log aggregation DB you self-host** — use a managed service or just `kubectl logs` with `jq` until query volume justifies the cost.

## 2. Scraper Reliability
- [ ] Add retry logic for failed GovInfo/congress.gov downloads (currently fatal on first error, no partial recovery)
- [ ] Implement graceful partial ingest — skip bad files and continue rather than aborting the entire run
- [x] Add structured logging to the Go scraper (currently uses `fmt.Println` / `log.Fatal`)
- [ ] Validate parsed XML/JSON against required fields before DB insert (silently drops malformed data today)
- [ ] Add bill parsing unit tests — two schema versions (3.0.0 + legacy) have zero test coverage
- [ ] Add integration test for the full XML → ParsedBill → DB pipeline

## 3. Distributed Cache (Redis)
- [x] Replace in-process cache with Redis so replicas share cache state
- [x] Make `POST /admin/clear-cache` clear shared keys instead of only one pod
- [x] Keep cached responses available across API pod restarts while Redis stays up
- [ ] Add Redis-focused observability, such as cache hit-rate or Redis availability checks

## 4. API Documentation
- [ ] Add OpenAPI/Swagger spec for all endpoints — no API docs exist today
- [ ] Auto-generate from route definitions using `@fastify/swagger`
- [ ] Publish interactive docs at `/docs` endpoint

## 5. Database Resilience
- [ ] Enable SSL for Postgres connections in production (currently `sslmode=disable`)
- [ ] Add a read replica for heavy analytical queries (`/explore` endpoints)
- [ ] Tune connection pool based on actual utilization (hardcoded min:2 max:20, no metrics to validate)
- [ ] Add materialized views for the most expensive `explore` queries (refresh daily after scraper completes)

## 6. Frontend Testing & SEO
- [ ] Add component tests for key pages (bill detail, vote breakdown, search)
- [ ] Add end-to-end tests (Playwright) for critical user flows: search → bill detail → cosponsors
- [ ] Improve meta tags / structured data for bill pages (better Google discoverability)
- [ ] Add error boundaries and loading states for failed API calls during static generation

## 7. CI/CD Pipeline
- [ ] Add GitHub Actions (or equivalent) for: lint, test, build on PR
- [x] Automate API and frontend image builds on merge to `main` for the Argo-managed path
- [ ] Add schema migration tooling (currently `schema.sql` is applied manually; no versioned migrations)
- [ ] Validate K8s manifests in CI (`kubeval` or `kubeconform`)

## 8. Security Hardening
- [ ] Implement secrets rotation mechanism (API secret key, DB credentials are static)
- [ ] Add audit logging for admin endpoints
- [ ] Add per-API-key rate limiting (current: per-IP only, bypassable via proxies)
- [ ] Ensure `SECRET_KEY` can't leak into logs or error responses

## 9. Data Pipeline Improvements
- [ ] Add a dead-letter queue for bills/votes that fail parsing — currently lost silently
- [ ] Track data freshness per congress (last successful ingest timestamp)
- [ ] Add a `/admin/status` endpoint showing last scraper run, bills ingested, errors encountered
- [ ] Consider incremental sitemap fetching instead of re-downloading the full GovInfo sitemap daily

## 10. Developer Experience
- [ ] Add a `Makefile` with common commands (`make dev`, `make test`, `make deploy`, `make scrape`)
- [ ] Document the local development workflow end-to-end (currently scattered across README, AGENTS.md, ARCHITECTURE.md)
- [ ] Add `.env.example` for local development (separate from `.env.prod.example`)
- [ ] Pin Go and Node versions in a `.tool-versions` or similar
