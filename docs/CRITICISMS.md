# Project Criticisms and Remediation Plan

This is a deliberately candid critique of CSearch as it exists in this repo.
The project has a strong core: Rust ingest, FastAPI reads, PostgreSQL as the
system of record, Redis fail-open caching, Nuxt presentation, and pgvector for
semantic retrieval are all reasonable choices. The main problems are not that
the stack is wrong. The main problems are drift, operational ambiguity, weak
validation, and a few places where promising prototypes have been allowed to
look more production-ready than they really are.

The goal of this document is to identify the highest-leverage improvements, not
to make the project feel bad about itself. Several of these issues are normal
for a fast-moving solo or small-team system. They become dangerous only if they
stay invisible.

## Executive Summary

The strongest criticisms:

1. The repo is polluted with generated data, virtualenv artifacts, duplicate
   "2" files, old deploy scripts, archived manifests, and stale docs. This
   makes it hard to know what is real.
2. Database schema ownership is muddy. There are bootstrap SQL files, dumps,
   idempotent runtime schema creation, and manual migration jobs, but no single
   migration system.
3. Deployment has too many active-looking paths: Argo CD, root `deploy.sh`,
   Cloudflare Pages, nginx frontend images, a Worker cache, and old S3/CloudFront
   docs. This increases the chance of fixing the wrong thing.
4. Semantic search is useful, but it is not yet a mature RAG product. It lacks
   hybrid ranking, evaluation, cost guardrails, query controls, and a clear
   generated-answer contract.
5. The API is too open for endpoints that can spend money or stress Postgres.
   CORS is broad, semantic search has no rate limit, and query length is not
   bounded.
6. The NLP/vector pipeline lacks production-grade integrity checks. A failed or
   partial shard run can be hard to distinguish from a good one.
7. Test and CI coverage do not match the blast radius. Images can be built and
   pushed without running the API tests, Rust tests, frontend typecheck, manifest
   validation, or semantic retrieval checks.
8. Observability is log-heavy but metric-light. There are useful logs and a
   `/freshness` endpoint, but not enough SLOs, alerts, or dashboards for data
   age, job success, semantic latency, embedding cost, and vector coverage.

## Priority Remediation Plan

If you only do five things, do these:

1. Clean the repo and make generated/runtime artifacts impossible to recommit.
2. Introduce real database migrations and make schema drift a CI failure.
3. Collapse deployment documentation and scripts down to one blessed path per
   environment.
4. Add semantic search guardrails and an evaluation suite before expanding RAG.
5. Add CI gates for tests, typechecks, k8s manifests, Docker builds, and docs
   link/source-of-truth checks.

## 1. The Repository Is Too Polluted To Be Trustworthy

### Criticism

The repo contains multiple categories of files that should not coexist with the
source tree:

- Duplicate conflict/copy files such as `AGENTS 2.md`, `DEPLOY 2.md`,
  `docs/engineering-guide 2.md`, `backend/scraper/src/db 2.rs`, and similar
  `* 2.*` files.
- Downloaded congressional data under paths like `backend/scraper/data/` and
  `backend/scraper/congress/data/`.
- A Python virtualenv-like tree under `backend/scraper/congress/env/`.
- Generated frontend output like `frontend/.output/nitro 2.json`.
- Large vendored/archive artifacts mixed with active code.
- Old docs that still describe Fastify, S3, CloudFront, Qdrant, or `cache.js`
  as if those are current.

This creates a trust problem. A new contributor cannot tell whether a file is
authoritative, historical, generated, accidental, or production-critical. It
also makes search noisy and expensive. The fact that a broad `rg` or `find`
walks thousands of data/generated paths is itself a maintainability smell.

### Remediation

Create a repo hygiene project with a hard end state:

1. Add or tighten `.gitignore` for:
   - `backend/scraper/data/`
   - `backend/scraper/congress/data/`
   - `backend/scraper/congress/env/`
   - `frontend/.output/`
   - `*.pyc`, `.venv/`, `target/`, generated caches, and local tarballs
2. Delete duplicate `* 2.*` source/docs files unless they are intentionally
   preserved under `docs/archive/`.
3. Move large source snapshots and downloaded data to object storage, local
   volumes, or documented fixture bundles.
4. Keep only small deterministic fixtures in git.
5. Add a CI check that fails on:
   - files matching `* 2.*`
   - committed virtualenv paths
   - committed `.output`
   - raw scraper data outside approved fixture directories
   - files over a chosen size threshold, for example 5 MB, unless allowlisted
6. If the repository history is already huge, consider a one-time history clean
   with `git filter-repo` or BFG after coordinating with any collaborators.

## 2. Documentation Has Too Many Competing Truths

### Criticism

The docs are valuable, but they are not consistently authoritative. Examples:

- `ARCHITECTURE.md` now describes the current FastAPI/Cloudflare Pages/pgvector
  path, while older docs still mention S3/CloudFront, Fastify, Qdrant, or Node
  route files.
- `docs/engineering-guide.md` references `backend/api/utils/cache.js` and
  Fastify/Pino even though the active API is Python/FastAPI.
- `DEPLOY.md`, `DEPLOY 2.md`, `docs/deployment.md`, root `deploy.sh`, and
  Argo manifests each tell overlapping deployment stories.
- `backend/nlp/README.md` reads partly like an aspirational standalone NLP
  service, while production semantic search is currently integrated into the
  main FastAPI app.

This documentation drift is not harmless. It causes real operational mistakes:
people will edit the wrong file, deploy the wrong manifest, or debug a retired
architecture.

### Remediation

Adopt documentation ownership rules:

1. Define one source-of-truth doc per topic:
   - Architecture: `ARCHITECTURE.md`
   - Deploy: `DEPLOY.md`
   - Local dev: `DEV_SETUP.md`
   - Cache: `docs/caching.md`
   - NLP operations: `backend/nlp/project-tarp/UPDATE.md`
2. Move outdated docs to `docs/archive/` with a banner at the top:
   `Archived: not the current deployment path`.
3. Update or delete docs that mention:
   - Fastify
   - `backend/api/utils/cache.js`
   - S3/CloudFront as the active production frontend
   - Qdrant as the active vector store
4. Add a docs lint script that scans active docs for retired terms and fails CI
   unless the file is under `docs/archive/`.
5. Add "Last verified against code" dates to high-level docs if you expect them
   to survive frequent architecture changes.

## 3. Schema Management Is Not Mature Enough

### Criticism

Database schema is one of the riskiest parts of this system, and it currently
has too many sources of truth:

- `backend/scraper/schema.sql` is described as the schema source of truth.
- `k8s/netcup-db/001-schema.sql` and `k8s/freya-db/001-schema.sql` bootstrap
  cluster databases.
- root `schema.sql` is a dump that includes the `nlp` schema and HNSW index.
- `backend/nlp/project-tarp/upserter.py` can create the `nlp` schema and vector
  tables at runtime.
- Some one-off Kubernetes Jobs apply specific migrations such as ZIP districts
  and audit history.
- `DEPLOY.md` explicitly says Argo CD does not manage migrations.

That is too loose for a data platform. The likely failure mode is silent drift:
dev and prod differ, new databases bootstrap differently than old databases,
and a code path works only because one cluster has a hand-applied table.

### Remediation

Introduce versioned migrations:

1. Pick a migration tool. Good options:
   - `sqitch` for SQL-first discipline
   - `Flyway` for simple numbered SQL migrations
   - `Alembic` if Python ownership matters more
   - `refinery` if Rust ownership matters more
2. Create a single `db/migrations/` directory.
3. Convert current bootstrap SQL into `0001_initial_public_schema.sql`.
4. Add `0002_nlp_bill_vectors.sql`, `0003_zip_districts.sql`, and so on.
5. Make all environments apply the same migration sequence.
6. Stop creating production tables opportunistically from `upserter.py`; let it
   validate schema and fail with a clear error instead.
7. Add CI that:
   - starts a clean Postgres with `pgvector`
   - applies all migrations
   - runs API route tests against that schema
   - runs a small scraper smoke ingest
   - runs a pgvector smoke query

Keep a generated schema dump if useful, but treat it as an artifact, not the
authoritative input.

## 4. Deployment Has Too Many Active-Looking Paths

### Criticism

The project currently has several deployment paths that appear plausible:

- Argo CD apps under `argo/applications/`
- active manifests under `k8s/netcup-*` and `k8s/freya-*`
- root `deploy.sh`, which still applies archived manifests
- Cloudflare Pages deployment through `frontend/deploy.sh`
- nginx frontend image deployment
- Cloudflare Worker API cache
- manual `kubectl create job` runbooks

Some of this is necessary. Too much of it is ambiguous. Root `deploy.sh` is
especially risky because it looks like a convenient entry point but applies
legacy manifests and builds image names that do not match the current API image
name everywhere.

### Remediation

Make deployment boring:

1. Rename root `deploy.sh` to something like `legacy-deploy.sh`, or move it to
   `k8s/archive/legacy/`.
2. Put a hard warning at the top of any retained legacy script.
3. Ensure `DEPLOY.md` says exactly:
   - how code reaches netcup
   - how code reaches freya
   - how frontend reaches Cloudflare Pages
   - how Worker reaches Cloudflare
   - how to manually run jobs
4. Use immutable image references or digest pinning for production rollouts
   instead of relying solely on `:latest`.
5. Prefer Kustomize overlays for environment differences instead of copy-pasted
   `netcup` and `freya` trees when the manifests are mostly identical.
6. Add CI jobs for:
   - `kubectl kustomize k8s/netcup-db`
   - `kubectl kustomize k8s/netcup-core`
   - `kubectl kustomize k8s/netcup-scraper`
   - the freya equivalents
   - `kubeconform` or `kubeval` validation

## 5. Semantic Search Is Useful, But Not Yet Production-Grade RAG

### Criticism

The semantic search path is strong enough to be useful, but it should not yet
be treated as a mature RAG system.

Current limitations:

- The public API retrieves bill chunks and metadata, but does not generate
  grounded answers.
- The frontend uses semantic search for arbitrary bill-list queries and falls
  back to keyword only on errors. Exact user intents like `HR 42`, sponsor
  names, or quoted phrases may be better served by keyword or direct lookup.
- There is no hybrid rank fusion between keyword and vector results in the
  production route.
- There is no retrieval evaluation suite with known queries and expected bills.
- Similarity score thresholds and labels are empirical UI heuristics, not
  measured relevance boundaries.
- The vote embedding path exists in scripts/docs, but is not exposed through
  the production API.
- The system has no visible per-query explanation beyond the matched chunk.

The risk is product trust. Semantic search can feel magical when it works and
arbitrary when it misses. Without evals, you cannot tell whether a change to
chunking, query embedding, HNSW settings, or model version improved or degraded
the product.

### Remediation

Productize retrieval before productizing answer generation:

1. Build a small retrieval eval set:
   - 50 natural-language policy queries
   - 25 exact bill-number/title queries
   - 25 sponsor/committee/procedure queries
   - expected relevant bills and unacceptable false positives
2. Track metrics:
   - recall@10
   - precision@10
   - MRR
   - latency p50/p95
   - OpenAI embedding cost per 1,000 searches
3. Add hybrid retrieval:
   - vector top-k from `nlp.bill_embeddings`
   - keyword top-k from `public.bills.search_document`
   - optional trigram exactness boost
   - Reciprocal Rank Fusion or a simple weighted score
4. Add query routing:
   - exact bill number -> direct lookup
   - short or quoted query -> keyword first
   - policy/natural-language query -> hybrid semantic
5. Expose the matched chunk and why it matched.
6. Only then add generated answers. The answer route should return citations,
   source bill ids, quoted evidence spans, and an "insufficient evidence" mode.
7. Treat model changes as migrations:
   - new embedding table or model column partition
   - backfill
   - eval
   - switch traffic
   - keep rollback available

## 6. The Vector Pipeline Needs Stronger Integrity Guarantees

### Criticism

The NLP pipeline is pragmatic, but it is still shaped like a batch prototype:

- `fetcher.py`, `content_hasher.py`, `chunker.py`, `embedder.py`, and
  `upserter.py` communicate primarily through directories of JSONL shards.
- There is no strong run manifest that proves which inputs produced which
  chunks, embeddings, model version, dimensions, and database rows.
- The upserter deletes and reinserts rows for affected bill ids. This can be
  correct, but it raises the stakes for partial failures.
- Nightly runs rely on incremental HNSW maintenance. That may be fine, but
  recall is not being measured.
- There is no obvious vector coverage dashboard by Congress, bill type, and
  latest source update.

The failure mode is subtle: the API can keep returning semantic results while
the vector corpus is incomplete, stale, partially loaded, or degraded.

### Remediation

Add pipeline integrity as a first-class concept:

1. Each pipeline run should write a manifest containing:
   - git SHA
   - congress
   - source data root
   - input bill count
   - changed bill count
   - chunk count
   - token count
   - embedding model
   - embedding dimensions
   - shard checksums
   - upserted chunk count
   - started/finished timestamps
2. `upserter.py` should validate:
   - all expected shards exist
   - all vectors are dimension 1536
   - model names match the target table policy
   - chunk count equals embedding count
3. Load into staging tables first, then swap or merge after verification.
4. Add `nlp.ingest_runs` and `nlp.ingest_run_items` tables for auditability.
5. Add a semantic coverage endpoint or dashboard:
   - chunks by Congress
   - chunks by bill type
   - max `created_at`
   - bills in public schema missing NLP chunks
   - embedding model distribution
6. Run scheduled recall checks against the eval set after index rebuilds or
   major upserts.

## 7. Public API Guardrails Are Too Weak

### Criticism

The API is currently permissive:

- CORS is configured with `allow_origins=["*"]`.
- `POST /search/semantic` can trigger OpenAI calls.
- Semantic query text has no clear maximum length.
- There is no visible rate limiting.
- There is no request budget, per-IP throttling, or abuse protection at the app
  layer.
- Expensive routes and cheap routes are treated similarly from a security and
  cost perspective.

That is fine for a quiet project. It is not fine if the site becomes popular,
gets crawled aggressively, or is intentionally abused. The semantic endpoint is
an especially obvious denial-of-wallet target.

### Remediation

Add layered guardrails:

1. Put Cloudflare rate limits or WAF rules in front of the API.
2. Add app-level rate limiting for semantic search:
   - per IP
   - per user token if auth exists later
   - stricter burst limits for unauthenticated users
3. Cap semantic query length, for example 500 or 1,000 characters.
4. Reject empty, repeated, or obviously machine-generated spam queries.
5. Cache query embeddings for normalized query text where privacy and product
   needs allow it.
6. Add daily/monthly OpenAI spend alerts.
7. Narrow CORS to known origins if the API is not intended as a completely open
   public API.
8. Add structured logs for semantic query length, latency, OpenAI status, and
   result count.

## 8. Freshness Is Still More Complicated Than It Should Be

### Criticism

The project has made real progress on freshness: scraper cache invalidation,
dual scraper schedules, Cloudflare deploy hooks, `/freshness`, and the Worker
cache are all pointed in the right direction. The criticism is that freshness
is still spread across too many layers:

- scraper writes Postgres and clears Redis
- NLP updater writes vectors and may trigger a Pages deploy sentinel
- Cloudflare Pages rebuilds static output
- optional Worker cache has a 5 minute fresh window and 24 hour stale window
- frontend may call either the API or the Worker depending on configuration

This makes it hard to answer the user-facing question: "How old is the data I
am looking at?"

### Remediation

Make freshness visible and measurable:

1. Add a "data freshness contract" to `ARCHITECTURE.md`:
   - p50 target
   - p95 target
   - worst-case target
   - what counts as fresh for bills, votes, and semantic chunks
2. Extend `/freshness` to include:
   - last successful scraper job timestamp
   - last successful NLP job timestamp
   - current vector coverage timestamp
   - frontend build timestamp if available
   - Worker cache age if request came through the Worker
3. Add a small frontend-visible freshness indicator on data-heavy pages.
4. Alert if:
   - scraper has not succeeded in 24 hours
   - NLP has not succeeded in 48 hours when source data changed
   - API latest bill update lags source update by more than target
   - frontend build timestamp is older than latest data update by more than
     target

## 9. Observability Is Mostly Logs, Not Operations

### Criticism

Structured logs are good, but they are not enough. The system needs metrics and
alerts for the things that define whether CSearch is healthy:

- scrape duration
- scrape changed rows
- skipped/failed file counts
- API latency by route
- Redis hit/miss rate
- Postgres query latency
- semantic search latency broken down into OpenAI and pgvector time
- OpenAI error rate and spend
- NLP chunk/embedding counts
- HNSW query latency and recall indicators
- frontend deploy age

Without these, incident response depends too much on manually reading logs and
remembering how the pipeline works.

### Remediation

Introduce a minimal operations layer:

1. Add Prometheus metrics or OpenTelemetry instrumentation to FastAPI.
2. Have the scraper emit a machine-readable run summary to Postgres or a
   metrics endpoint.
3. Store job run history in tables:
   - `ops.scraper_runs`
   - `ops.nlp_runs`
   - `ops.frontend_deploys` if feasible
4. Build Grafana panels:
   - data freshness
   - API latency and errors
   - Redis hit rate
   - semantic latency/cost
   - scraper/NLP job status
5. Add alerting rules for missed jobs, stale data, high API error rate, and
   semantic endpoint cost spikes.

## 10. CI Does Not Protect The Most Important Paths

### Criticism

The image build workflow builds and pushes images, but it does not appear to
systematically gate those images on:

- API tests
- Rust scraper tests
- frontend typecheck/build
- Worker typecheck
- Kubernetes manifest validation
- SQL migration validation
- Docker Compose/local dev validation
- semantic retrieval smoke tests

This is backwards. The more operationally complex a project becomes, the more
important it is that CI catches obvious breakage before pushing images tagged
as deployable.

### Remediation

Add CI stages before image publishing:

1. API:
   - install `backend/api`
   - run `pytest`
   - run a small integration test against Postgres
2. Scraper:
   - `cargo test`
   - `cargo clippy -- -D warnings` if feasible
   - smoke ingest against a tiny fixture
3. Frontend:
   - `npm ci`
   - `npm run generate`
   - `vue-tsc` or Nuxt typecheck if configured
4. Worker:
   - `npm ci`
   - `npm run typecheck`
   - `wrangler deploy --dry-run`
5. Infrastructure:
   - `kubectl kustomize` for every active k8s path
   - `kubeconform` validation
6. Database:
   - apply migrations to clean Postgres
   - verify expected extensions
   - verify representative indexes exist
7. Docs/repo hygiene:
   - fail on duplicate `* 2.*`
   - fail on generated directories
   - fail on retired architecture terms in active docs

Only push `:latest` images after these gates pass.

## 11. Local Development Is Probably Broken Or At Least Unreliable

### Criticism

Local development instructions and local tooling disagree with the current
architecture in several places:

- `docker-compose.yml` builds the API with context `./backend/api`, but
  `backend/api/Dockerfile` copies paths relative to the repo root.
- Some docs still say to use `npm` for the API even though the active API is
  Python/FastAPI.
- Local Postgres/schema setup is not clearly tied to the same migration path
  used in clusters.
- The NLP pipeline requires real source data and secrets, but there is no tiny
  deterministic local fixture path for semantic search.

If local dev is unreliable, every change becomes a cluster experiment. That is
slow and risky.

### Remediation

Create one blessed local path:

1. Fix `docker-compose.yml` so it builds the current images from correct
   contexts.
2. Add `make dev`, `make test`, `make smoke`, or equivalent scripts.
3. Include a tiny fixture corpus:
   - 2 bills
   - 1 vote
   - small SQL seed
   - small NLP chunk/embedding fixture using deterministic fake vectors
4. Let developers run:
   - Postgres with pgvector
   - Redis
   - API
   - frontend
   - optional Worker dev server
5. Document a no-secrets semantic test mode using fake embeddings or a checked
   fixture vector.

## 12. The Product Boundary Between Search, Explore, And RAG Is Blurry

### Criticism

The frontend and API expose several ways to ask questions of the corpus:

- latest bills
- keyword/fuzzy bill search
- semantic bill search
- vote search
- explore queries
- future vote embeddings
- experimental generated answers

These are technically different, but from a user perspective they overlap.
Without a clear product model, users may not know when to browse, search, use
Explore, or expect semantic results. The implementation can also drift into a
pile of endpoints rather than a coherent congressional research tool.

### Remediation

Define the product surface:

1. Browse: latest and filtered lists.
2. Find: exact bill, sponsor, committee, vote, or member lookup.
3. Search: hybrid keyword + semantic retrieval across bills and eventually
   votes.
4. Analyze: curated Explore queries with charts and parameter controls.
5. Answer: optional RAG answer generation with citations.

Then align routes and UI around those concepts. This will make future work like
vote embeddings, answer generation, and saved searches much easier to reason
about.

## Suggested 30/60/90 Day Plan

### First 30 Days

- Clean generated/runtime artifacts from the repo.
- Delete or archive duplicate `* 2.*` files.
- Update stale active docs or move them to archive.
- Fix local Docker Compose or replace it with a known-good dev script.
- Add query length limits and rate limiting for `/search/semantic`.
- Add CI gates for API tests, Rust tests, frontend build, Worker typecheck, and
  k8s manifest rendering.

### Days 31-60

- Introduce versioned SQL migrations.
- Convert public schema, NLP schema, ZIP districts, and audit history into the
  migration sequence.
- Add vector pipeline manifests and validation.
- Add semantic retrieval evals and baseline metrics.
- Add dashboards for freshness, job success, and semantic latency/cost.

### Days 61-90

- Implement hybrid retrieval and query routing.
- Add vote embeddings behind a measured API contract.
- Decide whether generated answers belong in the public product.
- Add an answer endpoint only after citations, evals, cost controls, and
  failure modes are defined.
- Consolidate deployment overlays and start using immutable image promotion.

## What Not To Do

- Do not rewrite the Rust scraper just because Rust is harder to onboard. It is
  working, and rewrite energy is better spent on schema, CI, and data quality.
- Do not add generated-answer RAG before retrieval quality is measured.
- Do not keep expanding Kubernetes manifests without pruning retired paths.
- Do not rely on `:latest` and manual memory for production promotion forever.
- Do not let docs remain "mostly right"; for infrastructure docs, mostly right
  can be worse than absent.

## The Core Bet Still Looks Good

The best part of this project is the architecture bet that congressional data,
search documents, and embeddings can live together in PostgreSQL. That is the
right simplification for this scale. The next phase should protect that bet by
making the repo smaller, migrations explicit, semantic quality measurable, and
operations boring.
