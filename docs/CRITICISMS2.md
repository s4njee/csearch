# Architectural Criticisms and Directions

A second, deliberately candid critique — this one focused on **system design**,
not process. Where [`CRITICISMS.md`](CRITICISMS.md) is about drift, validation,
and operations (now largely remediated), and [`../FINDINGS.md`](../FINDINGS.md)
is about concrete refactors (indexes, build cadence, vote embeddings), this
document is about the **structural bets**: how the workloads are partitioned,
where the boundaries are drawn, how identity and freshness flow through the
system, and where today's shape will resist tomorrow's load.

_Written 2026-05-30 against the code in this repo._

The core architectural bet — congressional data, full-text search documents, and
embeddings co-resident in one PostgreSQL — is still the right simplification at
this scale, and most of the stack is well chosen. The criticisms below are about
the seams that will strain first as traffic, data, and contributors grow. None of
them argue for a rewrite.

Each numbered item carries an **Observation**, a **Why it matters**, a short
**Direction** (the architectural options and trade-offs), and a concrete,
sequenced **Remediation plan**. The plans are staged so the riskiest changes —
model versioning and canonical identity — land behind the migration system and
the retrieval eval harness, with old and new paths runnable side by side for
rollback. Effort tags are rough: **S** ≈ a day, **M** ≈ a few days, **L** ≈ a
week-plus. Nothing here should be started before the model-versioning landmine in
§3 is defused.

## Executive Summary

The highest-leverage architectural issues:

1. **One Postgres runs four workloads with conflicting resource profiles** —
   low-latency reads, full-text search, vector ANN, and batch ETL with index
   rebuilds — on a single primary whose replica is not used for reads.
2. **Identity is string-typed and unenforced across schemas.** The `nlp` schema
   joins to `public.bills` by casting `billnumber::text`, with no foreign key,
   and votes reference bills by loose nullable columns.
3. **The embedding model is baked into rows but ignored at query time.** Search
   scans *all* embeddings regardless of `model`, so introducing a second model
   silently mixes incompatible vector spaces.
4. **OpenAI is a synchronous third-party dependency in the read hot path.**
5. **Three cache layers have three different invalidation models** and no
   end-to-end freshness contract; the Worker cache is not tied to the scraper's
   invalidation at all.
6. **The render model is an SSG/SPA hybrid** that splits freshness and SEO by
   page type in a way that is hard to reason about.
7. **The two "environments" do not match** — they bootstrap different schemas,
   carry dormant alternate database manifests, and are kept in sync by branch
   merges rather than promotion.

## 1. One PostgreSQL, Four Contradictory Workloads

### Observation

A single Postgres primary simultaneously serves: (a) low-latency OLTP reads from
the API, (b) `tsvector`/GIN full-text search, (c) `pgvector` HNSW approximate
nearest-neighbour search, and (d) the scraper's batch upserts plus the NLP
upserter's HNSW index maintenance. These have opposite resource profiles. The
HNSW rebuild path in [`upserter.py`](../backend/nlp/project-tarp/upserter.py)
requests `maintenance_work_mem = 16GB` and 6 parallel maintenance workers, while
the cluster is configured with `shared_buffers: 256MB` and
`maintenance_work_mem: 64MB` ([`k8s/netcup-db/cnpg-cluster.yaml`](../k8s/netcup-db/cnpg-cluster.yaml)).
The HA topology has a second instance, but the read pooler is `type: rw`
([`cnpg-pooler.yaml`](../k8s/netcup-db/cnpg-pooler.yaml)), so all reads still hit
the primary; the replica is failover-only.

### Why it matters

A full HNSW rebuild or a large backfill competes for buffers, I/O, and CPU with
live read traffic on the same node. The 16GB-vs-256MB mismatch means the index
build either fails, swaps, or only works because the documented cluster sizing is
not what is actually deployed — either way the resource model is not coherent.
There is a real ceiling here: the "one database for everything" bet is excellent
for *simplicity* and *consistency*, but it couples the latency of a user's
search to whatever batch job is running.

### Direction

- Route reads through a read replica (a `ro`/`rw` split pooler) so ANN and OLTP
  reads can scale off the primary.
- Run HNSW rebuilds against a replica or a dedicated vector node, then promote,
  rather than rebuilding in place on the primary (the `0007`-style staging-table
  swap the pipeline already half-implements per shard).
- Reconcile the memory model: either size the node for the index build or build
  with realistic `maintenance_work_mem`. The current numbers cannot both be true.
- Keep the co-resident bet; just stop letting batch maintenance and live reads
  share one instance's working set.

### Remediation plan

1. **Split reads from writes.** Add a read-only CNPG `Pooler` (`type: ro`)
   alongside the existing `rw` one, backed by the HA replica. Give the API a
   second DSN (`read_postgresuri`) and open two asyncpg pools; route all GET/read
   queries at the read pool. No write traffic moves (the API doesn't write).
2. **Take index builds off the primary.** Change the nightly upsert to never
   rebuild HNSW in place: build into a staging embedding table, build its index
   there, then swap (`ALTER … RENAME`) inside a transaction. The per-shard staging
   pattern already exists; extend it to the index.
3. **Reconcile the memory model.** Set the upserter's `--maintenance-work-mem` to
   a value the node can actually satisfy, or schedule the rebuild on a dedicated
   maintenance node/window. Add a preflight assertion that requested memory ≤ node
   memory so the 16GB-vs-256MB contradiction can't recur.
4. **Watch contention.** Add a Prometheus alert on primary CPU/IO saturation
   during ingest windows (extends `k8s/logging/alerts/`).

_Verify:_ run a load test of read latency while a full backfill runs; p95 stays
within the §8 freshness/latency contract. _Effort:_ M–L. _Safety:_ staging-swap
keeps the live index intact until the new one is ready.

## 2. Cross-Schema Identity Is String-Typed and Unenforced

### Observation

`public.bills` has a composite primary key `(billtype, billnumber, congress)`
with `billnumber` as `integer`. The `nlp` schema stores the same identity three
different ways — a denormalized `bill_id` text like `hr42-119`, plus separate
`congress`/`bill_type`/`bill_number` (the latter as **text**). The production
semantic join reconciles them at query time by casting:

```sql
LEFT JOIN public.bills b
  ON b.billtype = r.bill_type
 AND b.billnumber::text = r.bill_number   -- int cast to text every row
 AND b.congress = r.congress
```
([`routes/semantic.py`](../backend/api/src/csearch_api/routes/semantic.py)).
There is **no foreign key** between `nlp` and `public`. Votes reference bills by
nullable `bill_type`/`bill_number` columns with no FK either.

### Why it matters

- The `billnumber::text` cast defeats index usage on the join and is a latent
  correctness trap (leading zeros, formatting).
- Without referential integrity, the vector corpus can reference bills that no
  longer exist, and nothing detects it except the coverage endpoint I added.
- The same identity expressed three ways invites the three to disagree.

### Direction

- Adopt one canonical bill identity (e.g. a generated `bill_uid text` on
  `public.bills` equal to `billtype || billnumber || '-' || congress`) and make
  `nlp.bill_chunks.canonical_bill_id` a real foreign key to it.
- Type the join columns consistently so no per-row cast is needed.
- Give `votes` a real (nullable) FK to bills, or model the bill linkage
  explicitly as "may reference an external/unknown bill."

### Remediation plan

1. **Add a canonical key.** Migration `0007`: add a generated stored column
   `bill_uid text` to `public.bills` equal to `billtype || billnumber::text || '-'
   || congress`, with a unique index. (Generated, so backfill is automatic.)
2. **Make the NLP link a real FK.** Migration `0008`: ensure
   `nlp.bill_chunks.canonical_bill_id` matches `bill_uid`, backfill any mismatches,
   then add `FOREIGN KEY (canonical_bill_id) REFERENCES public.bills(bill_uid)` as
   `NOT VALID` and `VALIDATE CONSTRAINT` in a second step to avoid a long lock.
   Index the column.
3. **Drop the cast.** Once the FK exists, change the semantic join to
   `b.bill_uid = r.canonical_bill_id` (no `::text`), so it uses the index.
4. **Link votes.** Add nullable `votes.bill_uid` with the same FK; backfill from
   `(bill_type, bill_number, congress)`; leave null for external/unknown bills.
5. **Guard it.** Extend the `/search/semantic/coverage` check (and CI) to assert
   zero `nlp` rows whose `canonical_bill_id` has no matching `bill_uid`.

_Verify:_ `EXPLAIN` shows index use on the join; coverage reports 0 orphans.
_Effort:_ M. _Safety:_ keep the old string columns until the new join ships;
remove them in a later migration.

## 3. The Embedding Model Is Baked Into Data but Ignored at Query Time

### Observation

`nlp.bill_embeddings` stores a `model` column, but the retrieval query never
filters on it:

```sql
FROM nlp.bill_embeddings
ORDER BY embedding <=> $1::vector
LIMIT $4
```
The model name (`text-embedding-3-small`) and dimension (`1536`) are hard-coded
independently in [`routes/semantic.py`](../backend/api/src/csearch_api/routes/semantic.py),
[`upserter.py`](../backend/nlp/project-tarp/upserter.py), and the migration.

### Why it matters

This is the sharpest correctness risk in the system. The moment a second model
or dimension is introduced — exactly what an upgrade requires — the search query
will rank rows from **two incompatible vector spaces** against one query vector,
silently returning garbage for the mixed set. There is no online migration path:
changing models means a global re-embed and in-place index rebuild with no way to
serve old and new side by side, and the eval harness can't A/B them because the
query layer has no model dimension.

### Direction

- Make `(model, dimension)` a first-class retrieval dimension: the query selects
  one model's vectors, and the embedded query vector is tagged with the model it
  was produced by.
- Treat a model change as a blue/green migration: new embedding table/partition,
  backfill, eval (the harness already supports per-mode comparison), switch
  traffic, keep the old for rollback (this is documented in
  [`backend/nlp/eval/README.md`](../backend/nlp/eval/README.md) but the schema
  and query don't yet enforce it).
- Centralize the model/dimension constant so it cannot drift across the three
  call sites.

### Remediation plan

**Do this first — it is the cheapest fix to the biggest correctness landmine.**

1. **Single source for the model constant.** Move `EMBEDDING_MODEL` /
   `EMBEDDING_DIMENSIONS` into one module imported by both the API and the
   upserter; add a unit test asserting there is exactly one definition.
2. **Make model a retrieval dimension.** Choose per-model **tables/partitions**
   (e.g. `nlp.bill_embeddings` stays for the active model; a new model gets
   `nlp.bill_embeddings_<modeltag>`), which keeps each HNSW index in a single
   vector space. Record the "active model" in config, not in code.
3. **Constrain the query.** The retrieval query must read only the active model's
   table/partition, and the query vector must be tagged with the model that
   produced it; never compare across models.
4. **Blue/green a model change.** Backfill the new table, run
   `backend/nlp/eval/run_eval.py --mode vector` against old and new, flip the
   active-model config, keep the old table for rollback.
5. **Fail safe.** Add a CI/test guard that the retrieval SQL is scoped to one
   model, and a startup check that the active model matches the table it reads.

_Verify:_ a deliberate mixed-model fixture returns only active-model rows; eval
recall/MRR is reported per model. _Effort:_ M. _Safety:_ old model table stays
queryable for instant rollback.

## 4. OpenAI Is a Synchronous Dependency in the Read Hot Path

### Observation

`POST /search/semantic` calls OpenAI to embed the query inline, then queries
pgvector, all within the request. The query-embedding cache and rate limiter I
added soften this, but the structural fact remains: a user-facing read depends,
synchronously, on a third-party API for latency, availability, and cost.

### Why it matters

Every semantic search inherits OpenAI's tail latency and any outage. Spend is
coupled to traffic with no backpressure beyond the rate limiter. The system has
no fallback embedding path, so an OpenAI incident takes semantic search down
entirely (it currently degrades to keyword only on the frontend, which is good,
but the API route itself hard-fails).

### Direction

- Put a circuit breaker / timeout budget around the embedding call with an
  explicit keyword fallback in the API, not just the frontend.
- Consider a self-hosted embedding option for the query side (the corpus side can
  stay on OpenAI) so the read path has no hard external dependency.
- Longer term, separate "embed" from "retrieve" so the expensive external call
  can be cached, batched, or pre-computed for common queries.

### Remediation plan

1. **Add a timeout + circuit breaker** around `_embed_query`: cap the OpenAI call
   (e.g. 2s), and open a breaker after N consecutive failures with a cool-down.
2. **Fall back in the API, not just the UI.** On breaker-open or timeout, the
   `/search/semantic` route returns keyword results with a `degraded: true` marker
   instead of a 5xx, so the contract holds during an OpenAI incident.
3. **Lengthen and widen the embedding cache** for popular normalized queries, and
   optionally precompute embeddings for a curated hot-query list at deploy time.
4. **Remove the hard dependency (optional).** Evaluate a self-hosted query-side
   embedding model of the same family/dimension; keep corpus embeddings on OpenAI.
   This requires the model-versioning work in §3 to be in place first.
5. **Alert on it.** `/metrics` already exposes `openai_status`; add an alert on
   breaker-open / error rate.

_Verify:_ with OpenAI mocked to 500, the endpoint returns keyword results within
the latency budget, never a 5xx. _Effort:_ M.

## 5. Three Cache Layers, Three Invalidation Models

### Observation

Freshness passes through: Redis (application cache, **event-invalidated** — the
scraper clears `csearch:*` on data change), the Cloudflare Worker KV cache
(**time-based** 5-minute fresh / 24-hour stale, [`workers/api-cache/src/index.ts`](../workers/api-cache/src/index.ts)),
and Cloudflare Pages (**build-time** static output). The Worker has no link to
the scraper's invalidation — verified: it knows nothing about Redis or scrape
events.

### Why it matters

The three layers can disagree. The scraper can invalidate Redis and the API can
serve fresh data, while the Worker keeps serving a 5-minute-fresh / 24-hour-stale
copy of the same path, and the static site serves yesterday's build. The
user-facing question "how old is this byte?" has no single answer because each
layer answers it differently. The freshness contract I added to `ARCHITECTURE.md`
describes targets, but the layers don't share a mechanism to meet them.

### Direction

- Unify on one invalidation signal: when the scraper clears Redis, also purge the
  Worker KV namespace (or the relevant keys) and trigger the Pages rebuild — one
  event fans out to all layers.
- Or collapse layers: if the Worker does SWR well, Redis may be redundant for the
  cacheable GET routes; pick one edge cache and one app cache with a shared TTL
  policy.
- Make the freshness gauges I added the source of truth and assert the contract
  against them in CI/monitoring.

### Remediation plan

1. **Define one invalidation event.** The scraper's existing "data changed" signal
   (it already clears Redis) becomes the single fan-out trigger.
2. **Fan it out.** Extend the scraper's post-write step to also (a) bump a
   `cache-version` key the Worker reads and (b) call the Pages deploy hook — so one
   event invalidates Redis, the Worker, and the static build together.
3. **Make the Worker respect events.** Have the Worker treat a `cache-version`
   change as immediate staleness, overriding its time window; keep SWR only as the
   backstop between events.
4. **Assert the contract.** Tie the freshness gauges (`csearch_freshness_*`) to the
   contract in `ARCHITECTURE.md` and alert when a layer lags the event.
5. **Consider collapsing a layer.** If the Worker's SWR covers the cacheable GETs,
   evaluate dropping Redis for those routes (or vice-versa) to remove a model.

_Verify:_ after a scrape, a changed path served through the Worker reflects new
data within the contract, not the 5-minute window. _Effort:_ M.

## 6. The Render Model Is an SSG/SPA Hybrid That Splits Freshness by Page Type

### Observation

[`frontend/nuxt.config.ts`](../frontend/nuxt.config.ts) prerenders only the
top-level list routes (`/`, `/votes`, `/bills/hr`, `/committees`, …) with
`crawlLinks: false`. Bill **detail** pages are not prerendered — they are
client-rendered, resolving the API origin at runtime via an injected
`runtime-config.js` script. So list pages are static (stale until the next
build), while detail pages fetch live data on the client.

### Why it matters

This split is invisible and surprising: two pages on the same site have different
freshness, different SEO (only prerendered routes are crawlable HTML; detail
pages are empty shells to a crawler), and different performance characteristics.
[`FINDINGS.md`](../FINDINGS.md) attributes staleness to "every detail page
pre-rendered at build time," but the config shows the opposite for detail pages —
which means the freshness story itself isn't consistently understood. An
architecture you can't describe in one sentence is hard to operate.

### Direction

- Pick one model and apply it uniformly: edge SSR/ISR (e.g. render on a Worker
  with KV caching) gives fresh-and-crawlable for all page types; full SPA gives
  uniform freshness at the cost of SEO; full SSG gives uniform SEO at the cost of
  freshness.
- If the hybrid is intentional, document *why* per page type and make the split a
  deliberate policy rather than an artifact of the prerender route list.

### Remediation plan

1. **Pick the target render model.** Recommended: edge-render bill detail pages on
   a Worker/Nitro with KV SWR, so list and detail share one freshness + SEO model.
   Alternatives — uniform static (prerender details + event-driven rebuild, see
   `FINDINGS.md` §3) or uniform SPA (accept the SEO cost) — are acceptable if
   chosen deliberately.
2. **Make the policy explicit.** Whatever the choice, annotate per-route render and
   freshness intent in `nuxt.config.ts` so the split is a documented policy, not an
   artifact of the prerender list.
3. **Guard SEO.** Add a frontend/CI check that crawlable routes contain real
   content (e.g. a prerendered detail page includes the bill title).

_Verify:_ fetching a detail URL yields the freshness/HTML the documented policy
promises. _Effort:_ S to document + align; M–L for edge SSR.

## 7. The Two Environments Don't Match — and the Topology Is Ambiguous

### Observation

`netcup` (prod) and `freya` (dev) are described as mirrors, but:

- Both kustomizations deploy the custom `postgres-statefulset.yaml`, yet
  `k8s/netcup-db/` *also* contains `cnpg-cluster.yaml` + `cnpg-pooler.yaml` that
  are **not referenced** by its kustomization — a dormant alternate database
  topology sitting next to the live one.
- The two environments bootstrap **different schemas**: netcup loads
  `001-schema.sql` + `003-zip-districts.sql`; freya loads `001-schema.sql` +
  `002-audit-history.sql` ([the two `kustomization.yaml` files](../k8s/netcup-db/kustomization.yaml)).
  So prod has `zip_districts` but not the audit triggers; dev has the audit
  triggers but not `zip_districts`.
- Sync is by branch merge (`main` ⇄ `freya`) with copy-pasted manifest trees, and
  the image-update strategy differs (Argo Image Updater on freya, manual on
  netcup).

### Why it matters

"Test on freya before prod" is only meaningful if freya reproduces prod's
topology and schema. Today it reproduces neither: a bug that depends on
`zip_districts`, the audit triggers, or a database engine difference will not
surface in the mirror. The dormant CNPG manifests make it genuinely unclear what
the intended production database even is.

### Direction

- Collapse `netcup-*` and `freya-*` into a Kustomize base + per-environment
  overlays so the *only* differences are the few values that should differ. The
  divergent schema add-ons disappear once `db/migrations/` is the single applied
  sequence in both overlays.
- Remove or activate the dormant CNPG manifests — don't leave two database
  architectures in one directory.
- Promote by image digest, not branch merge, so dev and prod run identical
  artifacts.

### Remediation plan

1. **Collapse to base + overlays.** Create `k8s/base/{db,core,scraper}` and
   `k8s/overlays/{netcup,freya}` that patch only the values that should differ
   (replicas, hostnames, image-update strategy). Delete the copy-pasted trees.
2. **One schema everywhere.** Replace the divergent bootstrap configmaps with a
   migrate Job/initContainer that runs `db/migrate.py`. Migrations `0003`
   (zip-districts) and `0004` (audit) already unify what the two configmaps split,
   so both environments converge on one schema.
3. **Resolve the DB topology.** Either adopt CNPG in both overlays or delete the
   dormant `cnpg-cluster.yaml`/`cnpg-pooler.yaml` from `netcup-db`. Do not keep two
   database architectures in one directory.
4. **Promote by digest, not branch.** Point the Argo apps at an image digest
   bumped by a promotion step, so dev and prod run the identical artifact.
5. **Enforce parity.** Add a CI check that `kustomize build overlays/netcup` and
   `overlays/freya` differ only in an allowlisted set of keys.

_Verify:_ rendered overlays diff only in intended values; both bootstrap an
identical schema (assert via the migration ledger). _Effort:_ L.

## 8. Ingest Is a Two-Runtime Daily Monolith with Write Amplification

### Observation

The scraper image runs a Rust binary that orchestrates the vendored
`@unitedstates/congress` **Python** scraper via subprocess — two language
runtimes in one container. It runs once daily and reprocesses a full Congress,
skipping unchanged files by hash. Both the scraper (per bill) and the NLP
upserter (`replace_shard`) achieve idempotency by **deleting and reinserting**
all rows for an affected bill id. The NLP code lives in a **git submodule**
(`backend/nlp` → `csearch-nlp`), a boundary that CI and operators can desync from
the superproject.

### Why it matters

- Delete-and-reinsert per changed bill amplifies writes and, on the vector side,
  churns the HNSW graph (deletes degrade HNSW until rebuilt), which feeds back
  into §1's contention.
- A daily monolith means freshness is bounded by the batch cadence by
  construction, and a partial failure re-runs the whole stage.
- The submodule boundary means the most-changed component (the NLP pipeline)
  versions independently of the schema and API it depends on; the CI `database`
  job needs `submodules: recursive` precisely because of this split.

### Direction

- Move toward change-data-driven ingestion: process only the deltas the source
  actually changed, and prefer upsert-in-place over delete+reinsert where the
  primary key allows.
- Decide whether the NLP submodule boundary earns its cost. If the pipeline and
  schema must evolve together, vendoring it into the monorepo removes a class of
  desync bugs; if it's genuinely a separate product, give it its own contract and
  release cadence rather than a `git submodule` pin.
- Isolate the two runtimes (separate fetch and transform containers) so the
  Rust/Python coupling is an interface, not a shared image.

### Remediation plan

1. **Prefer upsert-in-place.** Where the primary key allows, replace the per-bill
   delete+reinsert with `INSERT … ON CONFLICT DO UPDATE`; reserve delete+reinsert
   for genuine structural changes (chunk count changes), reducing write churn.
2. **Batch vector maintenance.** Accumulate embedding deletes/inserts and rebuild
   HNSW on the staging-swap path from §1 rather than churning the live graph per
   bill; measure recall after with the eval harness.
3. **Isolate the runtimes.** Split the fetch (Python `@unitedstates/congress`) and
   transform (Rust) stages into separate containers sharing a volume/object store,
   orchestrated as initContainers in the existing CronJob, so the coupling is an
   interface rather than a shared image.
4. **Resolve the submodule boundary.** Either vendor `csearch-nlp` into the
   monorepo (if it must co-evolve with the schema) or give it a pinned,
   contract-tested release. Add a CI check that the submodule SHA is compatible
   with the current migration set.
5. **Only then** consider a second daily run for fresher data (`FINDINGS.md` §3).

_Verify:_ a single changed bill touches a bounded, in-place row set (measure rows
written); eval recall is stable after a churn-heavy run. _Effort:_ L.

## 9. Retrieval Is Two Engines with No Unifying Service

### Observation

Keyword search (`search_bills` SQL / FTS in [`routes/bills.py`](../backend/api/src/csearch_api/routes/bills.py))
and vector search ([`routes/semantic.py`](../backend/api/src/csearch_api/routes/semantic.py))
are independent code paths with independent ranking and result shapes. The RRF
fusion and query-routing modules I added (`hybrid.py`, `routing.py`) exist but
are not wired into a single retrieval surface; the frontend stitches the engines
together by falling back keyword-on-error.

### Why it matters

Every retrieval improvement — hybrid ranking, reranking, vote search, per-result
explanations, query routing in production — has to be threaded through multiple
routes and the frontend, because there is no one place that owns "given a query,
return ranked corpus results." This is why vote embeddings have been "almost
shippable" for a long time: the surface to extend is diffuse.

### Direction

- Introduce a retrieval service/module that owns query classification → engine
  selection → fusion → a single ranked result contract, with bills and votes as
  corpora behind it. The routes become thin callers; the frontend stops
  re-implementing fallback logic.
- This is the natural home for the `routing.py`/`hybrid.py` pieces and the place
  the eval harness should target.

### Remediation plan

1. **Create the service.** Add `csearch_api/retrieval.py` owning the pipeline:
   classify (`routing.py`) → select engine(s) → fuse (`hybrid.py`) → one ranked
   `RetrievalResult` contract, with bills and votes as corpora behind it.
2. **Thin the routes.** Make `/search/*` thin callers of the service and move the
   keyword-on-error fallback into it, so the frontend stops re-implementing fallback
   logic.
3. **Add votes.** Wire the existing `nlp.vote_*` tables (migration `0002`) in as a
   second corpus behind the same interface — no new route shape.
4. **Measure through it.** Point `backend/nlp/eval/run_eval.py` at the service so
   routing and hybrid fusion are evaluated end-to-end, not as detached helpers.
5. **Explain results.** Return the matched chunk / section uniformly so every
   result can show "why it matched."

_Verify:_ adding vote search requires no route change; the eval harness exercises
the service path. _Effort:_ M–L.

## 10. Domain Logic Lives in Hand-Assembled SQL and Comment-Parsed Explore Blocks

### Observation

API SQL is assembled by f-string concatenation of shared fragments
([`queries.py`](../backend/api/src/csearch_api/queries.py) constants spliced into
route SQL). The Explore feature parses curated SQL out of `explore.sql` by
scanning for `-- N. Title` comment delimiters
([`explore.py`](../backend/api/src/csearch_api/explore.py)), executes it via a raw
path, and returns the SQL text to the client. That file is shared with the
scraper image by a **build-time copy** (`backend/scraper/explore.sql` →
`backend/api/sql/explore.sql`).

### Why it matters

- String-assembled SQL has no compile-time checking; a renamed column is found at
  runtime. (A `sqlc` branch exists, suggesting this was felt.)
- Parsing executable queries out of comment structure is fragile: a stray
  `-- 5. ...` line reshapes the API.
- Sharing source by copying a file between two build contexts is the same
  "two truths" problem the first critique fought, in miniature.

### Direction

- Register Explore queries as first-class named artifacts (or database
  views/materialized views) rather than comment-delimited text; validate them in
  CI against the migrated schema.
- Consider typed query generation (sqlc-style or a thin query builder) for the
  hand-assembled route SQL so schema changes break the build, not production.
- Replace the build-time file copy with a single shared package or a generated
  artifact with a checksum, so the API and scraper provably agree.

### Remediation plan

1. **Register, don't parse.** Replace comment-delimited Explore parsing with a
   registry: each query a named entry (id, title, params, and either SQL or a view
   name), validated at load time against the migrated schema.
2. **Promote stable queries to views.** Move durable Explore queries into SQL
   views/materialized views owned by a migration; the API selects from them.
3. **Kill the file copy.** Replace the build-time `explore.sql` copy with a shared
   package or a checksummed generated artifact; extend `check-schema-drift.sh` to
   assert the API and scraper see identical content.
4. **Type the route SQL.** Adopt sqlc-style generation or Pydantic response models
   so a renamed column breaks CI rather than production.
5. **Stop echoing raw SQL** to clients unless explicitly intended (coupling / info
   leak).

_Verify:_ CI fails on a renamed column; Explore queries validate against the
migrated schema in the `database` job. _Effort:_ M.

## 11. No API Contract, Versioning, or Auth Seam

### Observation

The API exposes ad-hoc JSON shapes; the frontend depends on them positionally.
There is no `/v1`, no published schema, and no authentication/authorization layer
— expensive routes (semantic) and cheap routes share one open surface with no
notion of a caller.

### Why it matters

- The frontend and API are coupled by convention, so any response shape change is
  a silent breaking change. FastAPI generates OpenAPI for free, but nothing
  consumes it (no typed client, no contract test).
- With no auth seam, there is no place to hang per-caller quotas, tenancy, or
  paid/anonymous tiers later — the rate limiter I added is per-IP precisely
  because there is no identity to key on.

### Direction

- Define response models (Pydantic) and publish the OpenAPI schema; generate the
  frontend's types from it so shape drift is a compile error.
- Version the contract (`/v1`) before there are external consumers.
- Add a thin auth/identity seam (even if every caller is anonymous today) so
  quotas, abuse controls, and future tiers have somewhere to attach.

### Remediation plan

1. **Type the responses.** Add Pydantic response models to every route and set
   FastAPI's `response_model`, so the generated OpenAPI schema is accurate.
2. **Generate the client.** Publish the OpenAPI doc as a CI artifact and generate
   the frontend's TypeScript types from it (replacing hand-written
   `types/congress.ts`), so a response-shape change is a compile error.
3. **Version it.** Introduce a `/v1` prefix before any external consumer exists,
   and add a schema-snapshot contract test in CI.
4. **Add an identity seam.** Insert a thin auth middleware (token/API key,
   anonymous allowed) so rate limits, quotas, and future tiers can key on the
   caller instead of only the IP — the limiter added for §7 of `CRITICISMS.md` is
   per-IP precisely because there is no identity today.
5. **Publish a deprecation policy** for response shapes.

_Verify:_ the generated client compiles against the live API; a breaking shape
change fails the contract test. _Effort:_ M.

## What Is Already Well-Architected

So the critique is balanced:

- **Co-resident relational + vector + FTS in one Postgres** is the right call at
  this scale; it eliminates a whole class of cross-store consistency problems.
- **Fail-open Redis caching** is a sound resilience choice.
- **Content-hash-based change detection** in the scraper avoids needless work and
  cost.
- **Static-first frontend on Cloudflare** is cheap and fast for the read-mostly
  list pages.
- **GitOps with Argo CD** is a solid deployment foundation; the problem is the
  copy-paste, not the model.

## Suggested Sequencing

Architectural changes are riskier than the operational fixes, so sequence by
risk-reduced leverage:

1. **Model-versioned retrieval (§3).** Smallest change, removes the sharpest
   correctness landmine before anyone upgrades the model.
2. **Unify cache invalidation (§5)** and **read-replica routing (§1).** Directly
   protect latency and freshness as traffic grows.
3. **Canonical bill identity + FKs (§2).** Pays off everything downstream,
   including votes and the retrieval service.
4. **A retrieval service (§9)** and **the env base/overlay collapse (§7).**
   Structural simplifications that make every later feature cheaper.
5. **Everything else** as the relevant feature work touches it.

## What Not To Do

- Don't shard or leave PostgreSQL to "scale vectors." The single-store bet is
  good; fix workload isolation (§1) before considering a dedicated vector DB.
- Don't add generated-answer RAG on top of an unversioned retrieval surface (§9)
  and an unversioned embedding model (§3).
- Don't deepen the netcup/freya copy-paste; collapse it (§7) instead.
- Don't treat the SSG/SPA split (§6) as fixed; decide it on purpose.
