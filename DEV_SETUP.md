# Freya Dev Setup

How to make freya a development mirror of the netcup production deployment, so code/manifest changes can be iterated on freya without touching production.

## Goal

Freya should run the same stack as netcup:

- Standalone Postgres (statefulset) — not CNPG
- API + Redis
- Scraper CronJob
- Same env/config shape as netcup

Freya's Argo apps track a **`freya` branch split off current `main`**. Production (netcup) stays on `main`. Dev work lands on `freya` first; once validated, it gets merged/cherry-picked back to `main`.

---

## Branching model

```
main      ──●──●──●──●──────────────●──   (netcup, prod)
             \                     /
              └──●──●──●──●──●──●──●       (freya, dev — merged back when stable)
```

- Cut `freya` from `main` once. Do dev work on `freya`.
- When a change is ready for prod: merge/cherry-pick `freya` → `main`.
- Freya's Argo apps **only watch `freya`**, never `main`.

```bash
git checkout main && git pull
git checkout -b freya
git push -u origin freya
```

---

## Manifest layout

Create new paths on the `freya` branch, mirrored from netcup:

| Source (main)          | Destination (freya)   | Contents                              |
| ---------------------- | --------------------- | ------------------------------------- |
| `k8s/netcup-core/`     | `k8s/freya-core/`     | API + Redis + ingress + sealedsecret  |
| `k8s/netcup-db/`       | `k8s/freya-db/`       | Standalone Postgres statefulset       |
| `k8s/netcup-scraper/`  | `k8s/freya-scraper/`  | Scraper CronJob                       |

These exist **only on the `freya` branch**. `main` is unchanged.

Delete the current `k8s/mars*` paths from the `freya` branch (they'll still exist on `fastapi-api-rewrite` if needed).

---

## Argo Applications

Update the three freya-side Argo Application manifests on `main` (so both clusters can see the same app definitions under `argo/applications/`, or apply them directly to freya's argocd namespace — whichever is how they're currently installed).

### `argo/applications/csearch-freya-core.yaml`

- `targetRevision: freya`
- `path: k8s/freya-core`
- **Drop** the `argocd-image-updater.argoproj.io/*` annotations. Netcup-style deployments use `:latest` + `kubectl rollout restart`, not digest pinning.

### `argo/applications/csearch-freya-db.yaml`

- `targetRevision: freya`
- `path: k8s/freya-db`

### New `argo/applications/csearch-freya-scraper.yaml`

- Mirror `csearch-netcup-scraper.yaml`
- `targetRevision: freya`
- `path: k8s/freya-scraper`

All three keep `selfHeal: true` and `prune: true`.

---

## Open decisions

These need answers before the first apply. Each has a default picked in brackets — override if needed.

### 1. Ingress host [**decide**]

Netcup's `api-ingress.yaml` uses `api.csearch.org`, which resolves to netcup. Freya needs a different host or no ingress.

Options:

- **(a)** `api-dev.csearch.org` or `api-freya.csearch.org` — add DNS A record to freya's public IP, cert-manager issues a new cert. Clean, web-accessible.
- **(b)** Drop the ingress on freya; expose API via LoadBalancer on LAN (like current mars: `192.168.1.156:3000`). No public DNS, no TLS.
- **(c)** Keep the ingress manifest but don't point DNS at it. API still reachable via LoadBalancer or port-forward.

**Default: (b)** — simplest for dev, matches current freya behavior.

### 2. OPENAI_API_KEY (SealedSecret)

`k8s/netcup-core/csearch-api-openai-sealedsecret.yaml` is encrypted with **netcup's** sealed-secrets controller key. Copying it to freya won't decrypt — freya's controller has a different key.

Re-seal for freya:

```bash
# Get plaintext key (from netcup — you must have it or rotate)
kubectl --context=netcup get secret csearch-api-openai -o jsonpath='{.data.OPENAI_API_KEY}' | base64 -d
# → sk-proj-...

# Re-seal for freya
echo -n 'sk-proj-...' | kubectl --context=freya create secret generic csearch-api-openai \
  --from-literal=OPENAI_API_KEY="$(cat)" --dry-run=client -o yaml \
  | kubeseal --context=freya -o yaml > k8s/freya-core/csearch-api-openai-sealedsecret.yaml

git add k8s/freya-core/csearch-api-openai-sealedsecret.yaml
git commit -m "Reseal OPENAI_API_KEY for freya"
git push origin freya
```

Prereqs on freya:

- `sealed-secrets` controller installed in `kube-system` (or wherever netcup has it)
- `kubeseal` CLI locally with freya kubecontext access

### 3. Teardown of current freya state

Once Argo apps repoint, `prune: true` will delete existing resources not in the new manifests:

- CNPG `Cluster` + `Pooler` — **PVCs will be deleted**, Postgres data lost
- Frontend Deployment + LB service
- Mars-style scraper if deployed

**If freya has data you want to keep**, dump it first:

```bash
kubectl --context=freya exec -n default pg-cluster-1 -- \
  pg_dumpall -U postgres > freya-backup-$(date +%Y%m%d).sql
```

Then after new freya-db is running, restore:

```bash
kubectl --context=freya exec -i deploy/csearch-postgres -- \
  psql -U postgres < freya-backup-YYYYMMDD.sql
```

**If freya is just a test cluster**, let Argo prune — scraper will rebuild data from scratch (hours, not days).

### 4. Image tags

Netcup uses `:latest` for `csearch-fastapi` and `csearch-updater`. Freya, matching netcup, should also use `:latest`. Remove the digest-pinned `newTag:` entries from the copied kustomization.

```yaml
images:
  - name: registry.s8njee.com/csearch-fastapi
    newTag: latest
  - name: registry.s8njee.com/csearch-updater
    newTag: latest
```

After a new image push, trigger rollout on freya:

```bash
kubectl --context=freya rollout restart deploy/csearch-api
kubectl --context=freya rollout restart deploy/csearch-scraper   # if applicable
```

### 5. DNS / LAN access

If going with LoadBalancer (option 1b), confirm MetalLB or equivalent on freya assigns an IP in `192.168.1.x`. Current mars LB uses `192.168.1.156`. Reuse that IP or pick a new one in `api-lb.yaml` (service `loadBalancerIP`).

---

## Execution checklist

Do these in order. Each step is reversible until the Argo sync.

- [ ] Cut `freya` branch from `main`, push to origin
- [ ] On `freya`: copy `k8s/netcup-*` → `k8s/freya-*`
- [ ] On `freya`: delete old `k8s/mars*` paths (optional — they're orphaned once Argo repoints)
- [ ] Pick ingress option (§1) and edit `k8s/freya-core/` accordingly
- [ ] Re-seal OPENAI key for freya (§2)
- [ ] Back up freya Postgres if needed (§3)
- [ ] Update `images:` in `k8s/freya-core/kustomization.yaml` etc. to `:latest` (§4)
- [ ] Commit + push `freya` branch
- [ ] Update Argo Application manifests (`csearch-freya-core`, `csearch-freya-db`, `csearch-freya-scraper`) — `targetRevision: freya`, new paths, drop image-updater annotations
- [ ] Apply Application manifests to freya's argocd namespace (or let GitOps pick them up, depending on setup)
- [ ] Watch sync: `kubectl --context=freya get applications -n argocd -w`
- [ ] Verify API healthy: `curl <freya-api-endpoint>/health`
- [ ] Kick scraper manually once to populate data: `kubectl --context=freya create job --from=cronjob/csearch-scraper csearch-scraper-manual`

---

## Day-to-day dev flow after setup

```bash
# 1. Work on freya branch
git checkout freya
# edit code or manifests
git commit -am "…" && git push origin freya

# 2. CI builds csearch-fastapi:latest on push to freya (requires workflow update
#    — currently mars-images.yml only triggers on main). See "CI follow-up" below.

# 3. Roll out
kubectl --context=freya rollout restart deploy/csearch-api

# 4. When stable, promote to prod
git checkout main
git merge --no-ff freya       # or cherry-pick specific commits
git push origin main
# netcup's csearch-netcup-core syncs automatically
```

### CI follow-up

`.github/workflows/mars-images.yml` currently builds `:latest` only on pushes to `main`. For freya-branch dev to actually ship images, either:

- **(a)** Add `freya` to the workflow's `branches:` trigger — same `:latest` tag, freya pulls on restart. Risk: a freya push overwrites `:latest` that netcup also uses. **Don't do this without (b) or (c).**
- **(b)** Tag images by branch: `csearch-fastapi:freya` for freya pushes, `csearch-fastapi:latest` for main. Update `k8s/freya-core/kustomization.yaml` to pull `:freya`. Safer.
- **(c)** Build locally on freya (the host has working Docker per `DEPLOY.md`), push manually, restart. Same tag collision risk as (a) unless you use a branch tag.

**Recommended: (b)** — branch-tagged images. Worth a follow-up task once the base setup is running.

---

## Rollback

If freya setup breaks something:

```bash
# Revert Argo apps to previous targetRevision/path
git revert <commit>
git push

# Or edit directly
kubectl --context=freya edit application csearch-freya-core -n argocd
```

The `fastapi-api-rewrite` branch and `k8s/mars*` paths still exist, so the old freya config is recoverable.
