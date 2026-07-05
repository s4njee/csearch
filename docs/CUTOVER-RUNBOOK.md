# V2 corpus cutover runbook (netcup)

Rehearsed end-to-end on freya `csearch-v2` on 2026-07-05 (V2 plan Phase 5).
Measured there: **swap + API restart ≈ 22s per direction**; retrieval verified
E2E through the unchanged API SQL after each step. The same procedure covers
future embedding-model swaps and HNSW rebuilds — anything staged in
`nlp_stage`.

## Preconditions (all must hold)

1. `ops.check_invariants()` — 5/5 green on the target DB.
2. `nlp_stage.chunks` populated by a **successful** reconcile
   (`ops.reconcile_runs` latest row `success`, `executed == planned`).
3. Parity gate: `scripts/parity-harness.py` mean overlap@10 ≥ 0.9 against the
   current live corpus (see docs/PARITY-2026-07-04.md for methodology — slice
   to the shared corpus or the numbers are meaningless).
4. No pipeline running (suspend the v1 cronjob; check `pg_stat_activity`).
5. `nlp_prev` does not exist (previous cutover cleaned up).

## Procedure

```bash
# 1. swap (atomic; guards refuse empty stage / leftover nlp_prev)
kubectl exec -i postgres-0 -c postgres -- sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' \
  < scripts/swap-nlp-stage.sql

# 2. restart the API (clears cached plans; ~15s surge rollout)
kubectl rollout restart deploy/csearch-api && kubectl rollout status deploy/csearch-api

# 3. verify — all through the PUBLIC contract, not the DB:
#    - POST /v1/search/semantic returns results (E2E: embed -> ANN -> bills join)
#    - /freshness?detail=true shows chunk counts + last ingest (compat views)
#    - SELECT * FROM ops.check_invariants();  -- 5/5 green
```

## Rollback (any time before nlp_prev is dropped)

```bash
kubectl exec -i postgres-0 -c postgres -- sh -c '...psql...' \
  < scripts/rollback-nlp-swap.sql
kubectl rollout restart deploy/csearch-api
# v2 corpus is preserved as nlp_stage — fix and re-swap without rebuilding.
```

## Cleanup (after 7 quiet days)

```sql
DROP SCHEMA nlp_prev CASCADE;   -- reclaims the old corpus' disk (~25-30 GB on netcup)
```

## Gotchas earned during the rehearsal (do not relearn these)

- **Migration-image race:** Argo db-migrate hooks pull `csearch-db-migrate:latest`;
  after pushing new migrations, wait for Build Images to finish or the hook
  applies an old chain (bit us twice).
- **Verification pod selection:** during a rollout, `kubectl exec` on a pod
  selected by label may hit the terminating pod — select with
  `--field-selector=status.phase=Running` and retry once.
- **netcup-specific:** the API is rolled by Argo Image Updater on digest
  change, but the restart in step 2 is still required (same image, new
  conns). The scraper/data-pipeline cronjob must be suspended for the window
  (`kubectl patch cronjob csearch-data-pipeline -p '{"spec":{"suspend":true}}'`).
- **Disk (netcup Phase 6):** building `nlp_stage` alongside live v1 costs
  ~+30 GB transient; verified fits (82 GB free as of 2026-07-04). The HNSW
  build under maintenance_work_mem=1GB is slow-but-safe (E3 §3.5 sizing).
- **Seeding over WAN** (if ever needed again): server-side
  `COPY ... TO PROGRAM 'gzip > /tmp/x.gz'` in the pod → sha256-pinned,
  byte-offset-resumable download → LAN/local load. Never stream a multi-GB
  COPY through kubectl exec tunnels (died at 99.96% once).
