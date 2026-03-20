# CSearch Platform Architecture

The CSearch Congressional Data Platform is built as a highly-performant, monorepo architecture divided into three main components: a data ingest scraper, a REST API, and a static frontend. 

The primary goal of the infrastructure is to serve massive datasets of bills and voting data rapidly without overwhelming the central PostgreSQL database.

## System Components

1.  **Backend Scraper (`backend/scraper/`)**
    *   **Technologies:** Go, Python (scrapelib).
    *   **Role:** Scheduled daily (via Kubernetes CronJob at `00:00 UTC`), it pulls raw XML/JSON from GovInfo and congress.gov, parses it (skipping unchanged files using SHA-256 caching), and writes updates to the normalized Postgres database.

2.  **REST API (`backend/api/`)**
    *   **Technologies:** Node.js, Fastify, Knex.js.
    *   **Role:** Serves optimized JSON payloads of bills, actions, cosponsors, and analytic vote queries to the frontend.

3.  **Frontend Web App (`frontend/`)**
    *   **Technologies:** Nuxt 4 (Vue 3), TailwindCSS.
    *   **Role:** Provides the user interface. Production is statically generated (SSG) via `npx nuxt generate` and deployed globally to AWS S3 & CloudFront with the default API origin set to `https://api.csearch.org`. The `mars` development deployment runs the generated app behind nginx on k3s, where the API origin is injected at runtime from the Kubernetes manifest.

---

## Infrastructure Optimizations

### 1. Daily LRU Cache Architecture (The Refresh Workflow)
Because the platform's data is only updated once a day by the scraper, sending thousands of redundant queries to PostgreSQL for popular endpoints (e.g., `latest` bills, vote counting, explore queries) creates unnecessary load.

We utilize an in-memory **LRU Cache** within the Fastify Node process to hold query results for 24 hours. However, to guarantee data freshness the moment the scraper finishes updating the database, we rely on a staggered two-CronJob orchestration process:

#### The Deployment & Invalidation Timeline
*   **`00:00` (Midnight):** `csearch-updater` CronJob starts. It detects XML changes on GovInfo, parses them, and commits the new records to PostgreSQL.
*   **`01:00` AM:** `csearch-frontend-deployer` CronJob starts.
    1.  **Cache Invalidation:** Before doing anything, it sends a `POST` request to `api.csearch.org/admin/clear-cache`. This clears the Fastify LRU Cache across the API instances.
    2.  **SSG Generation:** It immediately runs `npx nuxt generate`. Nuxt fetches data from the Fastify API.
    3.  **Cache Warm-up:** Because the Fastify cache is now empty, it executes the heavy SQL queries directly against the freshly updated Postgres database. Fastify saves this fresh data to its LRU memory and returns it to Nuxt.
    4.  **S3 Sync & CloudFront Invalidation:** The static HTML is shipped to AWS S3, and the edge CDN cache is cleared.
*   **`00:35` AM to `23:59` PM:** For the next 23.5 hours, user browsers visiting the site (acting as SPA requests) receive their JSON data instantly from Fastify's RAM (`X-Cache: HIT`), saving massive load on the Postgres database.

### 2. Database Connection Pooling
Kubernetes horizontally scales the `csearch-api` Node.js pods based on traffic. 
*   **Postgres Limits:** The single underlying PostgreSQL database has a native ceiling for concurrent active connections (typically `100`).
*   **Knex Pool:** To prevent connection exhaustion under heavy load, Knex implements a connection pool configuration (`min: 2, max: 20`). This forces Fastify to safely reuse and lease active TCP connections instead of allocating unmanageable spikes of queries directly against the database instances.

### 3. Logging and Observability
The platform uses stdout as the logging transport so Kubernetes can collect logs without any extra agents in the hot path.

*   **API logging:** Fastify is configured with Pino JSON logs, request/response serializers, and redaction for the admin authorization header. A shared `onResponse` hook writes one structured completion line per request with latency, cache status, and route metadata.
*   **API context:** Route handlers add targeted analytics and audit events for search queries, cache clears, and slow explore queries. A shared error hook keeps failures tied to the active request context.
*   **Scraper logging:** The Go updater uses `log/slog` with JSON output to stdout. It records run start/end summaries, per-bill and per-vote ingest events, and warnings for parse/hash/insert failures.
*   **Python subprocess output:** The Go scraper re-emits the vendored Python scraper's stdout and stderr streams as structured log entries so they remain parseable alongside native Go logs.
*   **Log shipping:** A Fluent Bit DaemonSet tails `/var/log/containers/*.log`, enriches records with Kubernetes metadata, and forwards them to a configurable HTTP collector when `LOG_SHIP_HTTP_HOST` is set in `.env.prod`.
*   **Operational model:** This keeps the current stack lightweight while still making `kubectl logs` usable for debugging, ad-hoc analysis, and future log shipping to a managed sink.

---

## Deployment Process
Deployments into the cluster are handled primarily through scripts or CI/CD running standard `kubectl apply` commands against definitions residing in the `k8s/` configuration directory. 

*   **Database:** Configured through StatefulSets (`k8s/db/`)
*   **API:** Replicated via Deployment Services (`k8s/api/`)
*   **Scraper / Deployer:** Driven recursively by CronJobs (`k8s/scraper/` and `k8s/frontend/deploy-cronjob.yaml`)
*   **Frontend production:** Built by `frontend/deploy.sh`, then synced to S3 and invalidated through CloudFront
*   **Frontend dev (`mars`):** Served by the nginx container manifests in `k8s/frontend/mars-deployment.yaml` and `k8s/frontend/dev-service.yaml`
