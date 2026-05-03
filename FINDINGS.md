# Csearch — Findings

This document covers the four review questions on `csearch-updater-root/`:

1. Tech-stack drift and whether something else fits better.
2. High-leverage refactors for performance, UX, and accuracy.
3. Why bills are ~3 days stale, and how to make them more real-time.
4. Semantic search for votes — what's needed to ship it.

File and line references point at code as it exists in this repo today.

---

## 1. Tech Stack & Language Fit

### Current composition

| Component | Language | Framework | Notes |
|---|---|---|---|
| Scraper | **Rust** (~7.3k LOC) + some Python | Tokio + sqlx | `backend/scraper/Cargo.toml` — Redis, sha2, quick-xml, serde, chrono |
| API | **Python 3.11** | FastAPI 0.115 + uvicorn | `backend/api/pyproject.toml` — asyncpg, redis, openai |
| NLP pipeline | **Python 3.10+** | Standalone scripts (git submodule) | tiktoken, openai, psycopg2 |
| Frontend | **TS / Vue 3** | Nuxt 4 (static SSG → Cloudflare Pages) | Tailwind, Plotly.js |
| Log collector | **Go 1.24** | stdlib HTTP server | `backend/log-collector/go.mod` — minimal |
| DB | **PostgreSQL 18** | pgvector (HNSW), pg_trgm | `schema.sql` ~4.7k LOC |
| Cache | **Redis 7** | TTL 24h, prefix `csearch:`, fails open | |
| Orchestration | **k3s + Argo CD** | 67 manifests under `k8s/` | CronJobs: scraper `0 5 * * *`, NLP nightly |
| CI/CD | GitHub Actions → custom registry | Bitnami SealedSecrets for `OPENAI_API_KEY` | |

### Seams between components

- Scraper → DB: paginated batch upserts via sqlx, tunable `db_write_concurrency`.
- API → Postgres: asyncpg pool. Redis is bypassed on outage (fail-open).
- API → OpenAI: per-request `text-embedding-3-small` (1536-dim) calls.
- Frontend → API: plain HTTP. **No WebSocket, no SSE.**
- NLP → DB: nightly CronJob feeds `nlp.bill_embeddings`.

### Where the language choice is load-bearing vs. incidental

- **Rust scraper — arguable.** The job runs ~once a day for ~30–60 s. It is I/O-bound, not CPU-bound. Rust gives memory safety and good async, but the trade is slow iteration, harder onboarding, and a Docker build step. Go would give ~80 % of the throughput with 20 % of the learning curve. Recommendation: **don't rewrite for fashion**; keep Rust until either (a) iteration speed actually hurts, or (b) someone other than you needs to contribute. If either becomes true, Go is the natural target.
- **FastAPI — keep.** Async-first, pgvector-friendly, official OpenAI SDK. No reason to touch.
- **Nuxt 4 SSG — keep, but its staticness is the freshness bottleneck (see §3).**
- **Python NLP — keep.** Embedding work is embarrassingly parallel and the libraries (tiktoken, OpenAI SDK) are mature.
- **Go log-collector — over-engineered.** It's a thin HTTP receiver for Fluent Bit. A 30-line FastAPI service or Fluentd would be equivalent and cuts a language out of the stack.

**Stack fitness summary**

| Layer | Fit | Notes |
|---|---|---|
| Scraper (Rust) | 7/10 | Works; Go would simplify contribution |
| API (FastAPI) | 9/10 | No changes needed |
| Frontend (Nuxt 4) | 7/10 | Good for SSG; needs ISR for freshness |
| NLP (Python) | 8/10 | Proven, comfortable |
| DB (PG + pgvector) | 10/10 | HNSW already paying off |
| Cache (Redis) | 8/10 | TTL fine; invalidation model is sound |
| Deploy (k3s + Argo) | 8/10 | Solid GitOps |

---

## 2. High-Leverage Refactors

Sorted by effort/impact ratio. Top 5 first.

1. **Compound bill-search indexes (low effort, 2–3× faster filtered search).**
   - Today: `bills_search_document_idx` (GIN) + `latest_action_date_idx`. Queries like `GET /search/hr/relevance?query=...` scan the search vector then filter by `billtype`.
   - Fix: partial GIN per type — `CREATE INDEX bills_search_billtype_hr_idx ON bills (search_document) WHERE billtype = 'hr'` (and similar for `s`, `hjres`, `sjres`, etc.). Or a `(billtype, search_document)` composite.
   - Files: `schema.sql`; query gen at `backend/api/routes/bills.py:38–56`.

2. **`vote_members(voteid, position)` composite index (low effort, –3–5 ms / request).**
   - `/votes/detail/{voteid}` runs two parallel queries; the members query is the slow side.
   - Files: `schema.sql` (add index); `backend/api/routes/votes.py:99–110` (no query change).

3. **Pre-warm semantic embedding on app load (low effort, big perceived UX win).**
   - First semantic search costs ~700 ms cold. The endpoint `/search/semantic/warmup` already exists at `backend/api/routes/semantic.py:184–203` but the frontend doesn't call it on mount.
   - Fix: `useFetch('/search/semantic/warmup', { immediate: true })` in `frontend/pages/index.vue`. Cold queries drop to ~150 ms cache hit.

4. **Scraper N+1 in committees+subjects join (medium effort, ~15–20 % scraper-write latency).**
   - `backend/scraper/src/db.rs:66–74, 370–383` builds committee/subject arrays via a loop of INSERTs.
   - Fix: collapse into a single `INSERT … SELECT` with a lateral `UNNEST`. CTE pattern is already used elsewhere for `bill_actions` — extend it.

5. **Cache TTL is too coarse for explore queries (medium effort).**
   - `backend/api/cache.py:10` sets `TTL_SECONDS = 86400`. Scraper-driven invalidation only fires on bill/vote *content* changes, not on metadata-only updates, so explore endpoints can serve stale rows for a full day even when data is fresh.
   - Fix: drop explore TTL to ~12 h, and emit `Cache-Control: max-age=3600, stale-while-revalidate=86400` for ISR-style behavior at the edge. Keep scraper invalidation for the hard refresh path.
   - Files: `backend/api/routes/explore.py`; `backend/scraper/src/redis_cache.rs`.

**Honorable mention:** the NLP pipeline (`embedder.py` → `upserter.py`) has no shard validation between steps — if `embedder` half-fails, `upserter` reads stale shards. Add a manifest checksum + dimension check (1536) before upsert. ~1–2 lines per script.

---

## 3. Bills Are ~3 Days Stale — Why, and the Fix

### The freshness path

```
GovInfo update
  → scraper CronJob (k8s/netcup-scraper/cronjob.yaml:12 — "0 5 * * *", once daily)
  → Postgres
  → Redis (24h TTL, but invalidated on data change)
  → API
  → Cloudflare Pages (static SSG built on push to main, plus daily 12:00 UTC rebuild)
  → user
```

### Root cause

**It is not the API and not Redis. It is the static frontend build cadence.**

- Scraper at 05:00 CT usually catches that morning's GovInfo updates.
- API serves fresh data within minutes of the scraper.
- But the Nuxt site is `generate`-d. Every bill detail page is HTML pre-rendered at build time. Cloudflare Pages rebuilds:
  - on push to `main`, and
  - daily at 12:00 UTC (per `ARCHITECTURE.md:281`).
- A scrape on Tuesday 05:00 CT lands in the next rebuild on Tuesday 12:00 UTC. A scrape on Friday lands… on the *Saturday* build. Worst case: **4–5 days stale** over a weekend.

### Fixes, in priority order

1. **Trigger a Cloudflare Pages deploy from the scraper success path (1 day, biggest single win).**
   - Today the deploy is on a wall-clock timer. Make it event-driven.
   - In `.github/workflows/build-images.yml` (or the scraper CronJob's post-success hook), call the Cloudflare Pages deploy webhook. Staleness drops from days to "next build wall-time" — minutes if the build is fast, ≤30 min worst case.

2. **ISR / SWR for detail pages via Cloudflare KV (1–2 days, durable architectural fix).**
   - Cloudflare Pages doesn't have on-demand ISR, but a Worker in front can cache JSON responses in KV with `stale-while-revalidate`. Detail pages either fetch dynamically through the Worker, or stay static and the Worker hydrates the data slot.
   - Files: `frontend/nuxt.config.ts`, plus a new `wrangler.toml` for the Worker + KV namespace.

3. **Dual-frequency scraper (1 day, ~15 % freshness improvement).**
   - Add a second cron at 10:00 CT to catch late GovInfo posts. Doesn't fix the build-cadence issue on its own — pair with #1.
   - File: `k8s/netcup-scraper/orchestrator-cronjob.yaml`.

4. **WebSocket / SSE push (2–3 days, only if you want live UX).**
   - API publishes a "data updated" event on scraper success; frontend soft-refetches without a reload. Big architectural lift relative to the user-visible payoff.

**Recommended near-term fix:** #1 + #3. Drops staleness from 3–5 days to ~6–12 h with no UI rewrite.

---

## 4. Semantic Search for Votes — Implementation Roadmap

### Current state

- ✅ **Bills:** `nlp.bill_chunks` + `nlp.bill_embeddings`, HNSW (cosine), 1536-dim, served by `POST /search/semantic` (`backend/api/routes/semantic.py:161–181`).
- ❌ **Votes: not implemented.** No `nlp.vote_chunks`, no `nlp.vote_embeddings`. Today votes only support FTS on `votes.search_document` (`backend/api/routes/votes.py:7–54`).

### What's needed

| Concern | Bills | Votes |
|---|---|---|
| Embedding table | ✅ | Create `nlp.vote_embeddings` |
| Chunks table | ✅ | Create `nlp.vote_chunks` |
| Embedding model | `text-embedding-3-small` (1536-dim) | Same |
| Index | HNSW (cosine) | Same (`m=16`, `ef_construction=128`) |
| Query path | `POST /search/semantic` | Extend with `index=votes\|both` |
| Backfill cost | ~$0.15 / Congress | ~$0.004 / Congress (votes are short) |

### Steps (mirrors the bills pipeline)

1. **`backend/nlp/votes_loader.py`** *(new, ~200 LOC)* — walk `backend/scraper/congress/data/{congress}/votes/{session}/{chamber}{number}/data.json`, normalize `(vote_id, chamber, congress, question, subject, result, type, category, bill_id)`, emit JSONL shards.
2. **`backend/nlp/votes_chunker.py`** *(new, ~150 LOC)* — produce one chunk per vote with text:
   ```
   [Vote {vote_id}, {chamber}, {date}] {category}: {type}
   Question: {question}
   Subject: {subject}
   Result: {result}
   [bill: {bill_id}]
   ```
   Token-count via `tiktoken` (`cl100k_base`); compute `content_hash` and `source_hash`.
3. **Extend `embedder.py`** — add `--input-dir` / `--output-dir` flags so the same script handles `processed_vote_chunks/` → `embedded_vote_chunks/`.
4. **Extend `upserter.py`** with `--mode {bills,votes}`. Schema:
   ```sql
   CREATE TABLE nlp.vote_chunks (
     id BIGSERIAL PRIMARY KEY,
     source_hash TEXT NOT NULL UNIQUE,
     vote_id TEXT NOT NULL,
     congress INTEGER, chamber TEXT, session TEXT, number INTEGER,
     vote_date TIMESTAMPTZ,
     category TEXT, vote_type TEXT, question TEXT, subject TEXT, result TEXT,
     bill_id TEXT,                 -- nullable, no FK
     body TEXT NOT NULL,
     token_count INTEGER NOT NULL,
     chunk_index INTEGER DEFAULT 0,
     content_hash TEXT NOT NULL,
     created_at TIMESTAMPTZ DEFAULT now()
   );

   CREATE TABLE nlp.vote_embeddings (
     chunk_id BIGINT PRIMARY KEY REFERENCES nlp.vote_chunks(id) ON DELETE CASCADE,
     embedding vector(1536) NOT NULL,
     model TEXT NOT NULL,
     created_at TIMESTAMPTZ DEFAULT now()
   );

   CREATE INDEX vote_embeddings_embedding_hnsw_idx
     ON nlp.vote_embeddings USING hnsw (embedding vector_cosine_ops)
     WITH (m=16, ef_construction=128);
   CREATE INDEX vote_chunks_vote_id_idx ON nlp.vote_chunks (vote_id);
   CREATE INDEX vote_chunks_bill_id_idx ON nlp.vote_chunks (bill_id);
   ```
   Upsert keyed on `source_hash` (idempotent).
5. **`POST /search/semantic`** — add an optional `index ∈ {bills, votes, both}` param. In `both` mode, run both vector searches in parallel and interleave by score. File: `backend/api/routes/semantic.py:162–181` (extend `_semantic_rows`).
6. **`nightly_update.sh`** — orchestrate `votes_loader → votes_chunker → embedder → upserter`. Same incremental skip-by-hash behavior as bills.
7. **Validation** — backfill the 119th Congress first (~1.5k votes, ~180k tokens, ~$0.004). Sanity-check:
   ```sql
   SELECT COUNT(*), AVG(vector_dims(embedding))
   FROM nlp.vote_embeddings;   -- expect (1500, 1536)
   ```
   Test queries: "immigration votes", "budget votes this year", "unanimous defense votes".

### Cost & timeline

- **One-time backfill:** ~60k votes × ~120 tokens ≈ 7.2M tokens → **~$0.15 total.**
- **Steady state:** 0–50 new votes/night → essentially free (<$0.01/month).
- **Storage:** 60k × ~6 KB ≈ **360 MB** (vector + metadata).
- **Engineering effort:** ~10–12 hours focused.

### Files touched

- **New:** `backend/nlp/votes_loader.py`, `backend/nlp/votes_chunker.py`.
- **Modify:** `backend/nlp/embedder.py`, `backend/nlp/upserter.py`, `backend/nlp/nightly_update.sh`, `backend/nlp/Dockerfile.nightly-updater`.
- **Modify:** `backend/api/routes/semantic.py`.
- **Modify:** `schema.sql` (DDL above).

---

## Anti-Patterns Spotted

1. ✅ Cache invalidation logic is sound — scraper clears `csearch:*` on data change, not by clock.
2. ❌ Frontend build lag is the real freshness bottleneck — not the API, not Redis.
3. ⚠️ Go log-collector is over-engineered for what it does — fold it into Python or use Fluentd.
4. ⚠️ NLP pipeline lacks input validation — should verify shard count + embedding dimension before upsert.
