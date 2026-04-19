# Architecture

End-to-end runtime model for CSearch. Two clusters (netcup, freya), one database, one API image, one frontend.

---

## Clusters

| Cluster | Role | Argo CD location |
| --- | --- | --- |
| **netcup** | Production — Postgres, API, scraper, test frontend | Argo runs on netcup |
| **freya** | Secondary — API replica, NLP pipeline, Argo Image Updater | Argo runs on freya |

Both clusters run k3s with Traefik (netcup) or a LoadBalancer (freya).

---

## Data flows

### Ingest (scraper)

```
GovInfo / congress.gov
        |
        v
  Vendored Python scraper (backend/scraper/congress/)
  downloads raw XML/JSON bill and vote files
        |
        v
  Rust updater (backend/scraper/src/)
  - SHA-256 hash check → skip unchanged files
  - Parse XML/JSON → normalized structs
  - Upsert into PostgreSQL (public schema)
  - Invalidate csearch:* keys in Redis
```

Runs as a Kubernetes CronJob on netcup (`k8s/netcup-scraper/`). Coverage: bills from the 93rd Congress, votes from the 101st Congress.

### Read path (API → frontend)

```
Browser
  |
  v
Cloudflare Pages (csearch.org)   ← static Nuxt build
  |  (API calls)
  v
FastAPI (api.csearch.org / 192.168.1.156:3000)
  |
  +-- Redis cache (24h TTL)
  |     hit → return cached response
  |     miss ↓
  +-- PostgreSQL
        return + cache result
```

### Semantic search path

```
Browser POST /search/semantic {query}
  |
  v
FastAPI
  |
  v
OpenAI text-embedding-3-small API
  → 1536-dimensional embedding vector
  |
  v
PostgreSQL nlp.bill_embeddings
  (HNSW index, cosine distance via pgvector)
  → top 40 chunks ordered by embedding <=> $vector
  |
  v
Deduplicate to 20 unique bills
  → return [{bill_id, congress, title, body, similarity}]
```

### NLP embedding pipeline (nightly)

```
GovInfo bill text (HTLM/XML)
  |
  v
fetcher.py — download, skip already-cached
  |
  v
content_hasher.py — hash text, exit early if unchanged
  |
  v
chunker.py — split into section-aware chunks
  |
  v
embedder.py — OpenAI text-embedding-3-small (1536d)
  skip already-embedded chunk hashes
  |
  v
upserter.py — idempotent upsert into:
  nlp.bill_chunks       (text, metadata)
  nlp.bill_embeddings   (chunk_id, embedding vector, HNSW index)
```

Runs nightly as a CronJob on freya in the `csearch-nlp` namespace. Each step is idempotent — safe to re-run. Only new or changed bill text costs OpenAI API calls.

---

## Components

### PostgreSQL

- **Cluster:** netcup
- **Manifests:** `k8s/netcup-db/` → Argo app `csearch-netcup-db`
- **Schema source of truth:** `backend/scraper/schema.sql`

```
public schema
  bills, votes, members, committees, committees_bills, etc.

nlp schema
  bill_chunks      (id, bill_id, congress, title, status, body, chunk_type, section_header)
  bill_embeddings  (chunk_id, embedding vector(1536), HNSW cosine index)
  sync_state       (last_run bookkeeping)
```

Extensions: `pgvector`, `pg_trgm` (full-text search).

### FastAPI

- **Image:** `registry.s8njee.com/csearch-fastapi:latest`
- **Runtime:** Python 3.11, uvicorn, asyncpg, pydantic-settings, openai, redis
- **Source:** `backend/api/src/csearch_api/`
- **netcup manifests:** `k8s/netcup-core/api.yaml` → Argo app `csearch-netcup-core` (branch `main`)
- **freya manifests:** `k8s/freya-core/api.yaml` → Argo app `csearch-freya-core` (branch `freya`)

**Routes:**

| Method | Path | Description | Cached |
| --- | --- | --- | --- |
| `GET` | `/health` | DB connectivity check | No |
| `GET` | `/latest/{billtype}` | Latest bills by type | Yes |
| `GET` | `/search/{table}/{filter}` | Full-text bill search (relevance or date) | No |
| `POST` | `/search/semantic` | Semantic bill search via pgvector + OpenAI | No |
| `GET` | `/bills/{billtype}/{congress}/{billnumber}` | Bill detail with actions, cosponsors, votes, committees | No |
| `GET` | `/bills/bynumber/{number}` | All bills matching a number across congresses | No |
| `GET` | `/votes/{chamber}` | Latest votes by chamber | Yes |
| `GET` | `/votes/search` | Fuzzy vote search | No |
| `GET` | `/votes/detail/{voteid}` | Vote detail with member breakdown | No |
| `GET` | `/members/{bioguide_id}` | Member profile with bills and votes | No |
| `GET` | `/committees` | All committees with bill counts | No |
| `GET` | `/committees/{committee_code}` | Committee detail with bills | No |
| `GET` | `/explore` | List parameterized explore queries | No |
| `GET` | `/explore/{query_id}` | Run explore query | Yes |

**Semantic search request/response:**

```json
POST /search/semantic
{"query": "climate change carbon emissions", "congress_min": 110, "congress_max": 118}

→ [{
  "bill_id": "hr970-103",
  "congress": 103,
  "title": "Emergency Climate Stabilization Act",
  "status": "REFERRED",
  "body": "<matched chunk text>",
  "chunk_type": "section",
  "section_header": "FINDINGS.",
  "similarity": 0.473
}]
```

**Environment variables:**

| Variable | Description |
| --- | --- |
| `POSTGRESURI` | Postgres host |
| `DB_USER` | Postgres user |
| `DB_PASSWORD` | Postgres password |
| `DB_NAME` | Database name |
| `REDIS_URL` | Redis connection URL |
| `OPENAI_API_KEY` | OpenAI API key (required for `/search/semantic`) |
| `LOG_LEVEL` | Logging level (default: `info`) |
| `PORT` | Port (default: `3000`) |

### Redis

- **Manifests:** `k8s/netcup-core/redis.yaml`, `k8s/freya-core/redis.yaml`
- 24h TTL, key prefix `csearch:`
- Fails open — API falls back to Postgres when Redis is unavailable
- Scraper clears all `csearch:*` keys after successful ingest runs

| Route | Cache key |
| --- | --- |
| `GET /latest/{billtype}` | `csearch:latest_bills_<billtype>` |
| `GET /votes/{chamber}` | `csearch:latest_votes_<chamber>` |
| `GET /explore/{query_id}` | `csearch:explore_<query_id>` |

### Frontend

- **Source:** `frontend/` (Nuxt 4, Vue 3, TypeScript)
- **Public site:** Cloudflare Pages project `csearch` at `csearch.org`
- **Test site:** nginx container at `test.csearch.org` on netcup (`k8s/netcup-test-frontend/`)
- **API base:** configured at build time via `NUXT_API_SERVER`; can also be overridden at runtime via `/runtime-config.js`

**Search behavior:** when a query is entered, the frontend calls `POST /search/semantic` and displays results ranked by similarity score (cross-corpus, all congresses). Without a query, it fetches the latest bills for the selected category via `GET /latest/{billtype}`.

### Scraper

- **Image:** `registry.s8njee.com/csearch-updater:latest`
- **Source:** `backend/scraper/` (Rust) + `backend/scraper/congress/` (vendored Python)
- **Manifests:** `k8s/netcup-scraper/`, `k8s/freya-scraper/`
- Mounts host paths: `/srv/csearch/congress` and `/srv/csearch/data`
- Toggle bill/vote ingest independently with `RUN_BILLS` / `RUN_VOTES`

### NLP pipeline

- **Source:** `backend/nlp/` (git submodule → `github.com/s4njee/csearch-nlp`)
- **Cluster:** freya, namespace `csearch-nlp`
- **Model:** OpenAI `text-embedding-3-small`, 1536 dimensions
- **Index:** HNSW with cosine distance in `nlp.bill_embeddings`
- See `backend/nlp/IMPLEMENTATION.md` for full spec and `backend/nlp/project-tarp/UPDATE.md` for operational runbook.

### Logging

- All workloads write structured JSON to stdout
- Fluent Bit DaemonSet tails container logs (`k8s/logging/`)
- Ships to in-cluster HTTP collector or S3

---

## Deployment model

### Argo CD applications

| Application | Cluster | Git path | Branch | selfHeal |
| --- | --- | --- | --- | --- |
| `csearch-netcup-db` | netcup | `k8s/netcup-db` | `main` | Yes |
| `csearch-netcup-core` | netcup | `k8s/netcup-core` | `main` | Yes |
| `csearch-netcup-scraper` | netcup | `k8s/netcup-scraper` | `main` | Yes |
| `csearch-netcup-test-frontend` | netcup | `k8s/netcup-test-frontend` | `rscraper` | Yes |
| `csearch-freya-core` | freya | `k8s/freya-core` | `freya` | Yes |
| `csearch-freya-db` | freya | `k8s/freya-db` | `freya` | Yes |

**selfHeal is enabled on all apps.** Manual `kubectl` changes will be reverted within seconds. All changes must go through git.

### Image lifecycle

**netcup:** CI (`.github/workflows/build-images.yml`) builds `csearch-fastapi:latest`, `csearch-updater:latest`, and `csearch-frontend:latest` on every push to `main` touching `backend/api/**`, `backend/scraper/**`, or `frontend/**`. Argo picks up `:latest` on next sync.

**freya:** Argo Image Updater (`argocd-image-updater-controller` in `argocd` namespace) polls `registry.s8njee.com` every 2 minutes. When the `:latest` digest changes, it updates the Application spec in-cluster (no git commit) and Argo rolls out the new image automatically.

### Secrets

Secrets are encrypted with Bitnami SealedSecrets and stored in git:
- `k8s/netcup-core/csearch-api-openai-sealedsecret.yaml` — `OPENAI_API_KEY` for netcup
- `k8s/freya-core/csearch-api-openai-sealedsecret.yaml` — `OPENAI_API_KEY` for freya

Never commit plaintext secrets. Use `kubeseal` with the cluster's public key to generate SealedSecrets.

---

## Troubleshooting

**Argo reverted my `kubectl` change**
All Argo apps have `selfHeal: true`. Changes must be made in git and pushed to the watched branch.

**Semantic search returns 503**
`OPENAI_API_KEY` is not set in the pod. Check the `csearch-api-openai` SealedSecret is present and sealed for the correct cluster.

**Scraper finished but data looks stale**
- Redis cache hasn't expired — wait for 24h TTL or manually flush `csearch:*` keys
- Scraper may have skipped unchanged files (hash matched) — expected behavior

**Explore SQL change not showing after deploy**
Edit `backend/scraper/explore.sql` and copy to `backend/api/sql/explore.sql`, then rebuild and redeploy the API image.

**NLP embeddings not updating**
Check CronJob history: `kubectl get jobs -n csearch-nlp --context=freya`. `content_hasher.py` exits early if no bill text changed — this is expected.

**Frontend showing stale data**
The Cloudflare Pages build runs on push to `main` and daily at 12:00 UTC. Trigger manually via `workflow_dispatch` or run `deploy.sh` locally.
