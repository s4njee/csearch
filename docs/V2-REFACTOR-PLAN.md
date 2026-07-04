# V2 Refactor — Implementation Plan (freya, new namespace)

**Goal:** convert the ingest side of csearch from *silently degrading* to *loudly
self-checking*, with a data model where the bad states we hit in July 2026
(107K orphaned embeddings, stuck `running` ingest runs, a freshness table no one
was updating) are structurally impossible — and prove the whole thing on freya
in an isolated namespace before any of it touches netcup.

**Principles** (from the refactor discussion, 2026-07-04):

1. Read/serve path stays **fail-open** (unchanged). Ingest path becomes
   **fail-loud**: any invariant violation halts the run and never promotes state.
2. DB state = pure function of (scraped corpus + code version). The pipeline is
   a *reconciler*, not an appender.
3. Prefer structural guarantees (constraints, one table, atomic swap) over
   checks; prefer checks over hope. No new infra dependencies.
4. The Rust scraper, hybrid retrieval, and the public read API are **out of
   scope** — they work.

---

## Ground truth this plan builds on

| Fact | Consequence |
| --- | --- |
| freya cluster: 32 CPU / 64 Gi main node at ~8% CPU / 7% mem requested | a full second stack is trivial to host |
| freya **now runs ArgoCD** (managing `cb8`) | `csearch-v2` can be GitOps'd on freya's own Argo — no manual-apply drift |
| netcup node is tight (mem ~70% req) and its DB has the 20 GB HNSW index | prod cutover CANNOT be "second Postgres"; it must be **in-DB schema swap** |
| E3 shipped: `csearch-db-migrate` image + idempotent `db-migrate` Job, digest-pinned Postgres | v2 reuses these mechanisms as-is |
| ~2.8M embeddings ≈ real $ and ~hours to rebuild | green DB is **seeded from a netcup dump**, never re-embedded from scratch |
| v1 pathologies: orphaned embeddings, stuck runs, silent `refresh_data_versions`, stale image pins | each becomes a named invariant in Phase 0 |

## Blue/green — two distinct levels (the heart of this plan)

**Level 1 — environment blue/green (freya, validation).**
Blue = existing `default`-ns freya stack (also the E3 logical-replication mirror
target; leave it alone). Green = new namespace **`csearch-v2`**: own Postgres,
own API, v2 pipeline, invariant checker. Cutover on freya = repoint the LAN
frontend/ingress at the green API; rollback = point it back. Blue is never
modified, so rollback risk is zero.

**Level 2 — in-DB blue/green (the reusable cutover mechanism, rehearsed on
freya, later executed on netcup).** The v2 reconciler never rebuilds live
tables. Risky rebuilds (the v1→v2 migration itself; future embedding-model
swaps; HNSW rebuilds) write into a **stage schema**, pass the invariant + diff
gate, then cut over atomically:

```sql
BEGIN;
ALTER SCHEMA nlp       RENAME TO nlp_prev;
ALTER SCHEMA nlp_stage RENAME TO nlp;
COMMIT;                          -- atomic; rollback = rename back
```

then `kubectl rollout restart deploy/csearch-api` (belt-and-braces for cached
plans). `nlp_prev` is kept N days as instant rollback, then dropped. This is
how v2 lands on netcup **without a second database** the node can't afford.

---

## Target v2 data model

One table, orphans impossible:

```sql
CREATE TABLE nlp.chunks (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_hash     text NOT NULL UNIQUE,          -- content-addressed identity
    bill_uid        text NOT NULL,                 -- joins public.bills.bill_uid
    congress        int  NOT NULL,
    chunk_index     int  NOT NULL,
    text            text NOT NULL,
    tokens          int  NOT NULL,
    section_path    text,
    embedding       vector(1536) NOT NULL,         -- ← the invariant, structurally
    embedding_model text NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON nlp.chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX ON nlp.chunks (bill_uid);
```

- A chunk **cannot exist without its embedding** (`NOT NULL`), so the entire
  orphan class — and the `verify_counts` failure → manifest-never-promotes →
  full-reprocess loop it caused — is gone by construction.
- **Compat views** `nlp.bill_chunks` / `nlp.bill_embeddings` (projecting the old
  two-table shape) let the existing API SQL run unmodified during validation;
  the API query cleanup becomes a later, independent change.
- `nlp.reconcile_runs` replaces `ingest_runs`: records the *plan*
  (`to_add / to_update / to_delete` counts) and the *outcome*, with a CHECK
  that `finished_at IS NOT NULL OR started_at > now() - interval '6 hours'`
  enforced by the invariant checker (no eternally-`running` rows).

## The v2 reconciler (replaces nightly_update chunk/embed/upsert)

```
desired  = content-hash walk of scraped corpus     (per-bill doc hashes)
actual   = SELECT bill_uid, source_hash FROM nlp.chunks
plan     = diff → {add, update, delete} per bill
execute  = embed only add/update chunks; per-bill txn: DELETE bill's rows, INSERT new
verify   = post-run: DB matches desired manifest exactly; invariants green
promote  = write reconcile_run success + bump ops.data_versions
```

Fail-loud rules (hard exits, no warnings-and-continue):
- any changed bill that can't be resolved to a meta file → **abort** (v1 fix
  degraded to full scan; v2 aborts — a reconciler must never guess)
- post-run manifest/DB mismatch → abort, run marked `failed`, nothing promoted
- deletes exceeding a sanity threshold (e.g. >20% of corpus) → abort (protects
  against an empty/corrupt scrape wiping the DB)

---

## Phases

### Phase 0 — Invariants first (ships to the EXISTING stacks, no behavior change)
*This is the safety net the rest of the refactor is built against.*

- `db/migrations/0010_ops_invariants.sql`: `ops.check_invariants()` returning
  `(name, ok, detail)` rows:
  1. `chunks_embeddings_1to1` — no orphans either direction (v1 tables)
  2. `no_stuck_runs` — no `ingest_runs`/`reconcile_runs` `running` > 6h
  3. `freshness_current` — `max(ops.data_versions.refreshed_at)` ≥ last
     successful `ops.scraper_runs.finished_at` (catches the July-3 bug class)
  4. `single_embedding_model` per corpus
- `k8s/*/invariant-check-cronjob.yaml` (netcup + freya): daily, runs the
  `csearch-db-migrate` image → `psql -c "SELECT * FROM ops.check_invariants()"`,
  **exits non-zero on any red** + pings healthchecks.io (E4 dead-man's switch).
- **DONE 2026-07-04 (branch `refactor`):** `0010_ops_invariants.sql` +
  `invariant-check` CronJobs shipped; on netcup the checks went red exactly as
  predicted (129,119 orphans by then — today's failed run had stranded 21K
  more, proving the accumulation live) and the stuck Jul-3 run was flagged.
  Root cause found in the process: **netcup's live `bill_embeddings` predates
  the migration chain and was missing 0002's `ON DELETE CASCADE` FK** — the
  schema-as-defined made orphans impossible; the schema-as-deployed made them
  inevitable. `0011_nlp_embeddings_fk.sql` (idempotent purge + FK install, the
  structural fix pulled forward from Phase 1) applied to netcup in 37s.
  **All four invariants now green on prod.** Expect one more full-reprocess
  night (manifest still unpromoted from today's failed run), after which
  `verify_counts` passes, the manifest promotes, and nights go incremental.

### Phase 1 — v2 schema + migration chain
- **DONE 2026-07-04 (branch `refactor`):** `0012_nlp_v2_stage.sql` ships the
  v2 model **staged**: schema `nlp_stage` with the single `chunks` table
  (`embedding NOT NULL`), compat views (`bill_chunks`, `bill_embeddings`, and
  `ingest_runs` mapping the new persistent `ops.reconcile_runs` so
  `/freshness` + smoke keep working post-swap), plus a fifth invariant
  (`no_stuck_reconciles`). Design refinement over the original sketch: the
  stage schema + `scripts/swap-nlp-stage.sql` / `rollback-nlp-swap.sql`
  make bootstrap, v1→v2 cutover, and future model swaps **one identical
  mechanism** (schema-rename is OID-based, views survive the rename), and run
  history lives in `ops` so it persists across swaps.
- **Acceptance met + exceeded:** full chain green via `make db-smoke`; and the
  entire Phase-5 drill (transform fixtures → atomic swap → assert the whole
  v1 read contract through the views: retrieval join, coverage anti-joins,
  ingest_runs status, 5/5 invariants → rollback → v1 intact) now runs as
  `scripts/db-smoke-v2.sh` on **every CI build** (pg16 + pg18 verified).

### Phase 2 — Stand up `csearch-v2` on freya (GitOps'd)
- New dir `k8s/freya-v2/`: `namespace.yaml`, digest-pinned Postgres
  StatefulSet (20 Gi PVC, same 3 Gi limit shape as prod so perf findings
  transfer), `db-migrate` Job, Redis, API Deployment (DSN → v2 Postgres,
  LAN Service), `pipeline-v2` CronJob (`suspend: true`), `invariant-check`
  CronJob. Secrets created once by hand (`postgres-auth`, registry pull,
  `csearch-api-openai`).
- Register as an **Application on freya's own ArgoCD** (it already manages
  `cb8`) watching `k8s/freya-v2` on `main` — push = deploy, no manual drift.
- **DONE 2026-07-04:** `k8s/freya-v2/` live, GitOps'd by freya's own ArgoCD
  (`argo/applications/csearch-freya-v2.yaml`, Synced/Healthy). db-migrate hook
  applied the full chain 0000–0012 (`nlp_stage.chunks` present), **5/5
  invariants green**, `/health` + `/readyz` 200 (db+cache connected), empty
  corpus returns `[]`/nulls — data-shaped, not errors. Secrets provisioned
  (registry pull, fresh postgres-auth, api-secrets, openai copied).
  *Gotcha for the runbook:* the first hook Job raced the `csearch-db-migrate`
  image build and applied only 0000–0009 — hooks pull `:latest`, so after
  pushing new migrations, confirm Build Images finished before trusting a
  sync (or re-run the Job).

### Phase 3 — Seed green + prove the reconciler
- **Seed, don't re-embed:** `pg_dump` netcup's `nlp.bill_chunks` +
  `bill_embeddings` (congress 119), transform into `nlp.chunks` with one
  `INSERT … SELECT … JOIN` on the v2 DB. Cost: $0, minutes not hours.
- Run the reconciler against the same scraped corpus snapshot →
  **must compute a ~zero plan** (proves hash fidelity end-to-end).
- Then exercise every path deliberately: edit N fixture bills (update), add a
  synthetic bill (add), remove one (delete), corrupt one meta file (must
  abort). Verify `reconcile_runs` records each plan and invariants stay green
  throughout.
- **Acceptance:** all four paths behave; a kill -9 mid-run leaves invariants
  green and the next run self-heals (idempotence under crash).
- **STATUS 2026-07-04 — reconciler DONE and drilled; seed in flight:**
  * `reconciler.py` (csearch-nlp submodule) implements the full loop, reusing
    v1's `chunk_source_hash` so seeded v1 rows match reconciler-computed
    hashes bit-for-bit. Embeddings are **reused by hash** on bill replace —
    only genuinely new chunks hit OpenAI.
  * `scripts/reconcile-drill.sh` runs on every CI build: cold start → zero
    plan → delete-threshold abort → apply-with-reuse → **kill mid-run →
    invariants green → recovery run supersedes the abandoned audit row and
    converges on just the unfinished bill** (per-bill txns proven).
  * Reality check before seeding found the v2 `UNIQUE (bill_uid,
    chunk_index)` assumption false on the real corpus (59,773 dupes from
    multi-version bills) — dropped in migration 0013; `source_hash` is the
    identity.
  * Congress-119 seed netcup→freya-v2 streaming now (330,569 rows, verified
    by row count + ordered source_hash md5 on both ends when it lands).
  * **Remaining for Phase 3:** run the fetcher on freya-v2 (corpus volume +
    CronJob wiring), then the real-corpus reconcile — expect a small,
    explainable delta vs the seed, not zero, since GovInfo moves daily.

### Phase 4 — Parity harness (blue vs green)
- `scripts/diff-corpus.sh`: per-congress bill counts, per-bill chunk counts,
  top-K retrieval overlap (vector + hybrid) on `eval_set.json` queries between
  netcup (blue, v1) and freya green (v2 via compat views), latency sanity.
- Thresholds: counts explainable to zero; overlap@10 ≥ 0.9 on the eval set.
- **Acceptance:** written report checked into `docs/` — this harness is also
  the permanent gate for the eventual netcup cutover and future model swaps.

### Phase 5 — Cutover rehearsal (the drill that de-risks netcup)
1. **In-DB swap drill** on green: rebuild into `nlp_stage` via the reconciler,
   gate on invariants + diff, atomic schema-rename swap, restart API, verify
   retrieval; then **rollback drill** (rename back) and verify again. Time it.
2. **Environment cutover** on freya: point the LAN frontend at the v2 API;
   run for ≥ a week of suspended-→-re-enabled nightly reconciles.
- **Acceptance:** both drills documented as a runbook
  (`docs/CUTOVER-RUNBOOK.md`) with measured durations — that runbook *is* the
  netcup migration procedure.

### Phase 6 — netcup promotion (exit criteria only; separate change)
Promote only when, on freya v2: invariants green for **7 consecutive nightly
reconciles**, diff harness passes, both drills rehearsed. Netcup execution =
Phase 0 cleanup (done) → reconciler builds `nlp_stage` on netcup (disk: ~+30 GB
transient, 82 GB free — fits; HNSW build at the 1 GB `maintenance_work_mem`
already sized in E3 §3.5) → gate → swap → restart API → keep `nlp_prev` 7 days.

---

## Non-goals / guardrails
- No scraper rewrite, no retrieval-quality changes (eval harness must show
  *parity*, not improvement — improvements are separate PRs).
- No new infra (no Atlas/pgroll/Prometheus). The invariant checker is one
  CronJob + one SQL function.
- Blue freya stack (`default` ns) stays untouched — it remains the E3
  logical-replication mirror target and the rollback path.
- Sequencing dependency: none of Phases 1–5 touch netcup; only Phase 0 does,
  and it is read-only + one orphan cleanup.
