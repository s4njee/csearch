# Polish Backlog — Architecture Review 2026-07-01

Prioritized epics from a full-repo architecture review (ingestion, serving,
edge/frontend, infra/ops). Companion to [`CRITICISMS.md`](CRITICISMS.md) /
[`CRITICISMS2.md`](CRITICISMS2.md) (analysis) — this doc is the **work list**.

**Framing:** this is a solo-dev project that basically works. Every item below
is judged by one question: *does it reduce risk or toil without adding a new
moving part I have to maintain?* Items that failed that test are in the
explicit [Not Doing](#not-doing-deliberately) list at the bottom, so they stop
resurfacing in future reviews.

Effort tags as in CRITICISMS2.md: **S** ≈ a day, **M** ≈ a few days, **L** ≈ a
week-plus.

Priority order: **E1 backups → E2 pinned deploys → E3 freya mirror → E4
dead-man alerting → E5 ingestion hardening → E6 edge freshness nits → E7
retrieval unification.** E1 and E2 are independent and both small; do them
first in either order.

---

## E1 — Database backups and restore (P0, effort S–M)

**Why first:** one Postgres pod, one 30Gi `local-path` PVC, and no active
backup anywhere. Netcup has no backup job; freya's B2 backup exists but is
`suspend: true` (`k8s/freya-db/postgres-b2-backup-cronjob.yaml`). The corpus is
re-scrapeable from GovInfo, but a lost PVC still means days of re-scraping,
re-paying OpenAI for every embedding, and permanent loss of
`ops.scraper_runs` / `nlp.ingest_runs` history. This is the cheapest insurance
in the whole backlog.

- [ ] **Story 1.1 (S):** Port the freya B2 backup CronJob to `k8s/netcup-db/`
      (nightly `pg_dump -Fc` → B2), create the B2 credentials Secret, and add it
      to the netcup kustomization. Unsuspend the freya copy while you're there.
- [ ] **Story 1.2 (S):** Verify retention: confirm `prune-b2-backups.sh` (in the
      `postgres-backup-scripts` ConfigMap) actually runs and keeps a sane window
      (e.g. 14 daily + 8 weekly).
- [ ] **Story 1.3 (S):** Do **one real restore test** — `pg_restore` a fresh dump
      into a scratch database (docker-compose Postgres is fine), run the API
      smoke tests against it, and write the steps down as `docs/RESTORE.md`.
      A backup that has never been restored is a hope, not a backup.
- [ ] **Story 1.4 (S):** Export and store the SealedSecrets sealing key
      (netcup) somewhere off-cluster. If the cluster dies, every
      `*-sealedsecret.yaml` in the repo is otherwise unrecoverable.

**Done when:** a dump lands in B2 nightly from netcup, you have restored one
end-to-end, and the runbook exists.

---

## E2 — Auditable deploys: pin images to git SHA (P0, effort S)

**Why:** every manifest runs `:latest` with `imagePullPolicy: Always`. There is
no answer to "what commit is prod running?" and no rollback story beyond
guessing. CI **already pushes `:<git-sha>` tags** (`build-images.yml`) — the
manifests just don't use them. This is a small change that makes every deploy
and rollback a git operation, which is *less* process for a solo dev, not more.

- [ ] **Story 2.1 (S):** Set `images:` `newTag: <git-sha>` in the
      `k8s/netcup-*/kustomization.yaml` files instead of `:latest`; flip
      `imagePullPolicy` to `IfNotPresent`. Argo CD picks up the manifest change
      on push to `main` — no `rollout restart` needed anymore.
- [ ] **Story 2.2 (S):** Add a tiny `scripts/release.sh` (or Make target):
      takes a SHA (default `HEAD` of the last green CI run), rewrites the
      `newTag` entries, commits. That's the whole deploy process.
- [ ] **Story 2.3 (S):** Document rollback = `git revert` of a release commit,
      in `DEPLOY.md`. Delete the now-stale "rollout restart" instructions.

**Done when:** `git log` on `k8s/netcup-*/kustomization.yaml` is the deploy
history, and `:latest` no longer appears in active netcup manifests.

**Not included:** Argo Image Updater or digest automation — a new controller to
babysit; the release script does the same job with zero moving parts.

---

## E3 — Make freya an actual prod mirror (P1, effort M)

**Why:** "test on freya before prod" is currently illusory. Freya is deployed
by hand (`DEPLOY.md` admits ArgoCD doesn't manage it), has no
`schema_migrations` table, and bootstraps a *different* schema than netcup
(freya gets `002-audit-history.sql`, netcup gets `003-zip-districts.sql`).
The fix also **deletes complexity**: the migration runner becomes the only
schema path, and the mounted bootstrap SQL + `check-schema-drift.sh` go away.

- [ ] **Story 3.1 (M):** Make `db/migrate.py` the only schema mechanism in both
      environments — run it as a Job/initContainer on Postgres start (it's
      idempotent against an empty DB, so it covers bootstrap too). Ensure
      zip-districts and audit-history exist as migrations in the `db/migrations/`
      sequence so both environments converge to the *same* schema.
- [ ] **Story 3.2 (S):** On freya, apply the migration chain once manually and
      confirm `public.schema_migrations` matches netcup. From then on the Job
      keeps them aligned.
- [ ] **Story 3.3 (S):** Delete the mounted `001-schema.sql`/`002/003` bootstrap
      ConfigMaps from `k8s/{netcup,freya}-db/`, delete
      `scripts/check-schema-drift.sh`, and remove its CI step. Three copies of
      schema truth become one.
- [ ] **Story 3.4 (M):** Put freya back under GitOps. Cheapest path: register
      freya as a **second cluster in the existing netcup Argo CD** (no second
      Argo install) and point the `csearch-freya-*` Applications at it, watching
      the `freya` branch as the app manifests already claim. If cluster-to-cluster
      networking makes that painful, the fallback is a documented
      `kubectl apply -k` script — but then update `DEPLOY.md` and
      `ARCHITECTURE.md` to say so plainly, and delete the fictional Argo story.
- [ ] **Story 3.5 (S):** Reconcile the upserter's Postgres assumptions with the
      pod's actual resources: it configures `maintenance_work_mem` for an index
      build the 3GB-limit pod can't honor
      (`backend/nlp/project-tarp/upserter.py` vs
      `k8s/*/postgres-statefulset.yaml`). Set it to what the pod really has.

**Done when:** both environments run the identical migration sequence, freya
deploys from git, and no doc describes a deploy path that doesn't exist.

---

## E4 — Alerting that actually fires (P1, effort S)

**Why:** `k8s/logging/alerts/csearch-alerts.yaml` defines eight good
`PrometheusRule`s — and nothing evaluates them; no Prometheus is deployed. The
architecture degrades *silently by design* (fail-open Redis, circuit-breaker
fallback to keyword search, stale-while-revalidate), so the one thing you
cannot skip is knowing when it's degrading. A full kube-prometheus stack is
the wrong answer for one person; a dead-man's switch is the right one.

- [ ] **Story 4.1 (S):** Add success pings to a hosted dead-man's-switch
      (healthchecks.io free tier or similar): `curl` at the end of the
      orchestrator CronJob, the second scraper run, and the B2 backup job
      (from E1). The service emails you when a ping *doesn't* arrive — this
      covers "scraper stale >24h", "NLP stale >48h", and "backup missed"
      with zero cluster infrastructure.
- [ ] **Story 4.2 (S):** Add an external uptime check on
      `https://api.csearch.org/health` and `https://csearch.org` (UptimeRobot
      free tier or the same service). Covers "API down" and "site down".
- [ ] **Story 4.3 (S):** Move the unevaluated `PrometheusRule` file to
      `k8s/logging/archive/` with a README note ("no Prometheus deployed;
      re-instate if one arrives"). An alert file that fires nowhere reads as
      coverage you don't have. Keep the API's `/metrics` endpoint — it costs
      nothing and Grafana Cloud's free tier can scrape it later if you ever
      want dashboards (optional, **L**, not scheduled).

**Done when:** you would find out about a dead scraper, a dead API, or a
missed backup from an email, not from noticing stale data on the site.

---

## E5 — Ingestion hardening (P1, effort S)

Two small fixes to real failure modes; the rest of the pipeline's crash-safety
is genuinely good (per-bill transactions, hash-after-write, pending-manifest
promotion).

- [ ] **Story 5.1 (S):** The bincode hash stores are load-bearing and
      un-checksummed; `bincode::deserialize(&bytes)?` in
      `backend/scraper/src/hashes.rs` turns one corrupted byte into a
      permanently crash-looping CronJob. Catch the error, log loudly, and fall
      back to an empty store — worst case is one expensive full re-hash run,
      which the upserts make idempotent anyway.
- [ ] **Story 5.2 (S):** Stranded NLP shards: if the embedder crashes after
      writing some `embedded_chunks/` shards, `content_hasher.py` sees
      unchanged source text next run and skips the pipeline — the shards strand
      forever and the bills never reach the DB. Add a startup check in
      `nightly_update.sh`: if `embedded_chunks/` is non-empty but the pending
      manifest was never promoted, resume from the upsert stage (or wipe the
      shard dirs and force reprocess). Either is fine; pick the simpler.
- [ ] **Story 5.3 (S):** Write the scraper↔API Redis contract down: the scraper
      hardcodes the API's `csearch:*` key namespace
      (`backend/scraper/src/redis_cache.rs`). One sentence in both
      `backend/api/README` and `backend/scraper/README` ("this prefix is a
      cross-service contract; change both or neither") is enough — no code
      change needed.

---

## E6 — Edge freshness nits (P2, effort S)

The 5-layer cache chain (Pages HTML → worker version poll → KV fresh window →
KV SWR window → origin) is mostly earned complexity, and the deploy-hook work
in [`tasks.md`](tasks.md) already fixes the biggest staleness source (static
HTML rebuilds). Three residual sharp edges:

- [ ] **Story 6.1 (S):** `workers/api-cache` fetches `/cache-version` with no
      timeout — if origin hangs, every edge request stalls behind it. Wrap the
      origin fetch in a ~3s `AbortSignal.timeout` and fall through to the
      existing "unversioned" sentinel on failure.
- [ ] **Story 6.2 (S):** AI-summary worker: it runs LLM inference before
      knowing the bill exists, so garbage bill numbers burn Workers AI quota on
      an unauthenticated endpoint. Fetch the bill *first*, return 404 on miss,
      only then prompt. While in there: fold the bill's `latest_action_date`
      into the KV key so a summary can't outlive the bill data it describes,
      and drop the hardcoded LAN IP from the CORS allowlist.
- [ ] **Story 6.3 (S):** Frontend API-origin plumbing has four write paths
      (nuxt config fallback, baked `runtime-config.js`, docker-entrypoint
      rewrite, k8s env). Don't refactor — just document the precedence chain in
      `frontend/README` so future-you can debug "which origin won" in one read.

---

## E7 — One retrieval path for prod and eval (P2, effort M)

**Why:** `backend/api/.../retrieval.py` was extracted as the retrieval service
layer, and the eval harness + MCP server use it — but the production route
(`routes/semantic.py`) runs its own parallel implementation of routing, hybrid
fusion, and degradation. The retrieval eval is a CI **hard gate** that measures
code production doesn't run. That quietly invalidates the gate.

- [ ] **Story 7.1 (M):** Make `routes/semantic.py` call `retrieval.py` for
      routing/fusion/degradation and delete the duplicated logic. Diff
      production responses before/after on a handful of queries; the eval
      harness is the safety net here.
- [ ] **Story 7.2 (S):** Extract the three copies of the fuzzy-search SQL
      expression (bills / votes / routing) into one shared helper. Pure
      deletion, no behavior change.

**Explicitly deferred from this epic:** unifying the MCP server's response
projection with the API's — it's drift-prone but harmless drift; the MCP tools
are additive consumers. Revisit only if a projection bug actually bites.

---

## Not doing (deliberately)

Recorded so future reviews (and future me) don't re-litigate them. Each of
these adds a moving part or a migration that a solo project doesn't need while
"everything sorta works":

- **Kustomize base/overlay refactor of `k8s/`.** The netcup/freya copy-paste is
  real, but the trees are stable and the churn risk of a big restructure
  outweighs the dedup win today. Do it opportunistically if a change ever has
  to touch both trees in a non-trivial way. (E3 removes the worst duplication
  — the schema — anyway.)
- **Postgres read replica / connection pooler.** CRITICISMS2.md §1 is right
  about the four-workload contention *at scale you don't have yet*. Backups
  (E1) address the risk that matters now. Revisit when p95 latency or the
  nightly index build actually hurts.
- **Prometheus/Grafana/Alertmanager stack in-cluster.** Replaced by E4's
  dead-man's switch. Grafana Cloud free tier is the upgrade path if wanted.
- **Argo Image Updater / digest-pinning automation.** E2's release script does
  the job with no controller.
- **Auth, API versioning (`/v1`), per-user rate limits for MCP.** The API is
  deliberately public and read-only; per-IP limits plus the Traefik MCP
  middleware are adequate until there's abuse evidence.
- **Pagination unification across all routes.** Real inconsistency, low blast
  radius, purely additive API surface work. Batch it with the next real API
  feature.
- **Rewriting the scraper in Go / language consolidation.** FINDINGS.md
  already reached the right verdict: don't rewrite for fashion.
