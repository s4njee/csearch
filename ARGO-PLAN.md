# ArgoCD Plan for Deploying CSearch to the `mars` Cluster

This plan revises the earlier draft so it matches how this repository actually deploys to the `mars` Kubernetes context today.

The main goal is to move the `mars` dev stack to ArgoCD with the least risky path first. The naming standard should come from the existing netcup manifests, and `mars` should be brought into alignment before ArgoCD becomes the source of truth.

## 1. Scope

### In scope for the first ArgoCD rollout

- standardize `mars` workload names to the netcup convention
- bring the canonical API, Redis, and frontend resources under ArgoCD
- keep any `mars`-specific exposure resources clearly separate from canonical workload names

### Second-phase candidates after manifest reconciliation

- database resources for `mars`
- scraper resources for `mars`
- any persistent volume or PVC resources needed by the scraper

### Explicitly out of scope for this `mars` plan

- Production API deployment under `k8s/api/`
- Production scraper CronJob under `k8s/scraper/`
- S3/CloudFront frontend deploys driven by [`frontend/deploy.sh`](/Users/sanjee/Documents/projects/csearch-updater-root/frontend/deploy.sh)
- The root [`deploy.sh`](/Users/sanjee/Documents/projects/csearch-updater-root/deploy.sh) as a whole-cluster replacement on day one
- [`k8s/api/dev-service.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/api/dev-service.yaml), which fronts `csearch-api` rather than the `api-dev` deployment

## 2. Corrections to the Original Draft

The original plan had the right GitOps direction, but a few parts did not match the current repo:

1. It treated this as a full-cluster migration.
   For `mars`, we already have repo manifests that describe the current behavior in [`k8s/dev/api.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/dev/api.yaml) and [`k8s/frontend/mars-deployment.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/frontend/mars-deployment.yaml). They are useful references, but the Argo-managed end state should be a standardized `k8s/mars/` set using the netcup names.

2. It assumed we must move the entire `k8s/` tree into `base/` and `overlays/` before using ArgoCD.
   That is unnecessary churn. Kustomize can reference the existing YAML files directly, so we can adopt ArgoCD incrementally.

3. It assumed `envsubst` is the main blocker for `mars`.
   That is true for parts of production, but the current `mars` manifests are already mostly static and Argo-friendly.

4. It used generic image examples that do not match current `mars` usage.
   `mars` currently uses:
   - `registry.s8njee.com/csearch-postgres:latest`
   - `registry.s8njee.com/csearch-api:redis`
   - `registry.s8njee.com/csearch-frontend:latest`
   - `registry.s8njee.com/csearch-updater:latest`

5. It did not call out the biggest GitOps risk: mutable image tags.
   ArgoCD works best when manifests point at immutable tags such as commit SHAs. Reusing `latest` or `redis` will make rollouts harder to reason about and easier to miss.

6. It blurred the frontend deployment models.
   Production frontend deploys are static-site uploads to S3/CloudFront, while `mars` runs the nginx container from [`frontend/Dockerfile.nginx`](/Users/sanjee/Documents/projects/csearch-updater-root/frontend/Dockerfile.nginx) and injects `NUXT_API_SERVER` at runtime.

7. It assumed the repo's `mars` database and scraper manifests match the live cluster.
   They do not. On March 21, 2026, the `mars` cluster had:
   - `statefulset/postgres` and `service/postgres`
   - `cronjob/csearch-goscraper`
   - `persistentvolumeclaim/csearchpvc`

   The repo's dev manifests currently define different names:
   - [`k8s/dev/db.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/dev/db.yaml) creates `postgres-dev`
   - [`k8s/dev/scraper.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/dev/scraper.yaml) creates `scraper-dev`
   - [`k8s/dev/nfs-pvc.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/dev/nfs-pvc.yaml) creates `congress-nfs-pvc`

   We should not bring those under ArgoCD until we decide whether to align the manifests to the live resource names or replace the live resources deliberately.

## 3. Naming Standard

Yes, we can standardize on the netcup names, and that is the better long-term direction.

The key rule should be:

- canonical workload names match netcup
- optional `mars`-only access points may keep a suffix if they are environment-specific wrappers

Recommended canonical names:

| Role | Canonical name |
|---|---|
| API Deployment/Service | `csearch-api` |
| Redis Deployment/Service | `csearch-redis` |
| Postgres StatefulSet/Service | `postgres` |
| Postgres headless Service | `postgres-headless` |
| Scraper CronJob | `csearch-updater` |
| Frontend Deployment/Service | `csearch-frontend` |

Current `mars` drift to clean up:

| Current `mars` name | Standardized target |
|---|---|
| `api-dev` | `csearch-api` |
| `redis-dev` | `csearch-redis` |
| `csearch-frontend-dev` | `csearch-frontend` |
| `csearch-goscraper` | `csearch-updater` |
| `postgres-dev` in repo only | `postgres` |
| `congress-nfs-pvc` in repo only | decide whether to replace or align to the live PVC before Argo adoption |

For `mars`-specific external access, it is fine to keep separate service names if they are just wrappers. Examples:

- `csearch-frontend-lb`
- `csearch-api-lb`

That keeps the actual app identity standardized while still allowing environment-specific ingress patterns.

## 4. Recommended Repository Shape

Add a small `mars`-specific manifest set that uses the netcup names, then place a Kustomize overlay on top of that:

```text
k8s/
├── mars/
│   ├── api.yaml
│   ├── redis.yaml
│   ├── frontend.yaml
│   ├── api-lb.yaml
│   ├── frontend-lb.yaml
│   ├── db.yaml
│   ├── scraper.yaml
│   └── pvc.yaml
└── overlays/
    └── mars/
        ├── core/
        │   └── kustomization.yaml
        └── scraper/
            └── kustomization.yaml

argo/
└── applications/
    ├── csearch-mars-core.yaml
    └── csearch-mars-scraper.yaml
```

Why split `core` and `scraper`?

- `core` gives us the deploy path we care about first: API, Redis, and frontend.
- `scraper` depends on storage and currently does not match the live `mars` resource names, so it is safer to add after that is reconciled.
- The `k8s/mars/` manifests should use canonical netcup names, but keep `mars`-specific settings such as replica counts, runtime API origin, and optional LoadBalancer services.

## 5. Kustomize Overlays

### 5.1 `mars` core overlay

Create [`k8s/overlays/mars/core/kustomization.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/overlays/mars/core/kustomization.yaml):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../mars/api.yaml
  - ../../../mars/api-lb.yaml
  - ../../../mars/redis.yaml
  - ../../../mars/frontend.yaml
  - ../../../mars/frontend-lb.yaml

images:
  - name: registry.s8njee.com/csearch-api
    newTag: sha-REPLACE_ME
  - name: registry.s8njee.com/csearch-frontend
    newTag: sha-REPLACE_ME
```

Notes:

- The `name` value should match the image repository already present in the manifests.
- Do not directly reuse the production API manifest as the `mars` base until its secret handling is split away from `envsubst`.
- The `mars` base should reuse the netcup naming convention and labels, while keeping `mars`-specific values where needed.
- Use real immutable tags, not `latest`.

Recommended `mars` patches in this overlay:

- keep `csearch-api` as the service name, but point the frontend runtime config at `http://csearch-api`
- reduce replica counts if `mars` should stay single-replica
- add or keep a separate LoadBalancer service only if `mars` needs direct LAN access

### 5.2 `mars` scraper overlay

Do not create this overlay until the repo manifests are reconciled with the live `mars` resources.

Create [`k8s/overlays/mars/scraper/kustomization.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/overlays/mars/scraper/kustomization.yaml):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../mars/pvc.yaml
  - ../../../mars/scraper.yaml

images:
  - name: registry.s8njee.com/csearch-updater
    newTag: sha-REPLACE_ME
```

Before using that overlay, choose one of these paths:

1. Change the repo manifests so they manage the current live resources first, then rename the non-standard ones to the canonical names as part of the rollout.
2. Schedule a controlled replacement on `mars` so the scraper and storage resources are recreated directly under the canonical names.

Until that decision is made, keep the scraper outside the first ArgoCD rollout.

## 6. Image Tag Strategy

This is the part that matters most for reliable GitOps.

### What to avoid

- `:latest`
- branch-like mutable tags such as `:redis`

### What to use instead

- commit SHA tags such as `:4a2b9d2`
- or another immutable build identifier

### Why this matters

- ArgoCD only reacts to Git state, not "something in the registry changed."
- If the manifest still says `:latest`, there may be no spec change to apply.
- The frontend on `mars` currently uses `imagePullPolicy: IfNotPresent`, which makes mutable tags even less reliable.

Recommended normalization:

1. Keep `latest` only as a convenience tag if you want it for humans.
2. Make the Kustomize overlay point to the immutable SHA tag.
3. Stop using `csearch-api:redis` as the deploy tag in the Argo-managed path.

## 7. Secrets and Credentials

There are two separate credential problems to solve.

### 7.1 ArgoCD access to the Git repo

The repo remote is currently:

```bash
git@github.com:s4njee/csearch.git
```

If the repository is private, ArgoCD will need repository credentials:

- either an SSH deploy key for `git@github.com:s4njee/csearch.git`
- or an HTTPS repo URL plus token-based credentials

Do this before creating the `Application`, otherwise sync will fail immediately.

### 7.2 Kubernetes secrets used by workloads

For `mars`, the most important existing secret is the image pull secret:

- `registry-s8njee-pull`

Recommended approach:

- Manage `registry-s8njee-pull` as a Sealed Secret or another GitOps-safe secret source.
- Leave the current plain-text dev database credentials alone for the first pass if speed matters.
- As a follow-up, convert the hardcoded Postgres credentials in [`k8s/dev/db.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/dev/db.yaml), [`k8s/dev/api.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/dev/api.yaml), and [`k8s/dev/scraper.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/dev/scraper.yaml) to `Secret` references.

For `mars`, I would not block the initial ArgoCD rollout on cleaning up the dev DB password unless you want to do that now, especially because the first Argo phase does not need to take ownership of the database manifests yet.

## 8. Install ArgoCD on `mars`

Install ArgoCD into the `mars` cluster:

```bash
kubectl --context mars create namespace argocd
kubectl --context mars apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Access the UI locally:

```bash
kubectl --context mars port-forward svc/argocd-server -n argocd 8080:443
```

Initial admin password:

```bash
kubectl --context mars -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

## 9. ArgoCD Applications

### 9.1 Core app

Create [`argo/applications/csearch-mars-core.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/argo/applications/csearch-mars-core.yaml):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: csearch-mars-core
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:s4njee/csearch.git
    targetRevision: main
    path: k8s/overlays/mars/core
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 9.2 Scraper app

Create [`argo/applications/csearch-mars-scraper.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/argo/applications/csearch-mars-scraper.yaml):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: csearch-mars-scraper
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:s4njee/csearch.git
    targetRevision: main
    path: k8s/overlays/mars/scraper
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply them:

```bash
kubectl --context mars apply -f argo/applications/csearch-mars-core.yaml
```

Recommended order:

1. Apply `csearch-mars-core`
2. Verify the existing `postgres` dependency, plus api, redis, and frontend, are healthy
3. Only after manifest reconciliation, apply `csearch-mars-scraper`

## 10. Mars Migration Sequence

To standardize names safely on `mars`, do this in order:

1. Treat the netcup names as canonical.
2. Update the `mars` manifests so selectors, services, and environment references use:
   - `csearch-api`
   - `csearch-redis`
   - `csearch-frontend`
   - later, `csearch-updater`
3. Change the frontend runtime target from `http://api-dev` to `http://csearch-api`.
4. Remove the old duplicate `api-dev` and `redis-dev` resources after the standardized replacements are healthy.
5. Rename the frontend deployment/service on `mars` from `csearch-frontend-dev` to `csearch-frontend`.
6. Reconcile scraper and storage names before bringing them under ArgoCD.
7. After the names are stable, let ArgoCD own those canonical resources.

Important migration note:

- Because `mars` already has a live `csearch-api` deployment and service, do not attempt to run a second Argo-managed `csearch-api` with conflicting selectors in parallel.
- The clean path is to converge on the existing canonical names and delete the older `*-dev` resources once traffic has moved.

## 11. CI/CD Changes

ArgoCD should become the deploy mechanism, but image builds still belong in CI.

### New flow

1. CI builds and pushes:
   - `registry.s8njee.com/csearch-api:<sha>`
   - `registry.s8njee.com/csearch-frontend:<sha>`
   - later, optionally `registry.s8njee.com/csearch-updater:<sha>`
   - later, if the `mars` database manifest is brought under Argo, `registry.s8njee.com/csearch-postgres:<sha>`
2. CI updates the tag values in:
   - [`k8s/overlays/mars/core/kustomization.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/overlays/mars/core/kustomization.yaml)
   - [`k8s/overlays/mars/scraper/kustomization.yaml`](/Users/sanjee/Documents/projects/csearch-updater-root/k8s/overlays/mars/scraper/kustomization.yaml)
3. CI commits that manifest change back to Git.
4. ArgoCD detects the Git change and syncs `mars`.

### What `deploy.sh` should still do after this

- Production-oriented workflows can continue using [`deploy.sh`](/Users/sanjee/Documents/projects/csearch-updater-root/deploy.sh) until you are ready to migrate them separately.
- `mars` should stop relying on manual `kubectl apply` once the Argo apps are stable.

## 12. Validation Checklist

After the first sync on `mars`, verify:

```bash
kubectl --context mars get applications -n argocd
kubectl --context mars get pods
kubectl --context mars get svc
kubectl --context mars get cronjob
```

Specific checks:

1. `csearch-api` is running and ready.
2. `csearch-api` can reach the in-cluster `postgres` service and `csearch-redis`.
3. `csearch-frontend` is serving traffic and points to `http://csearch-api` through `NUXT_API_SERVER`.
4. Any extra `mars` LoadBalancer service points at the standardized frontend or API selectors.
5. If phase two is enabled later, the scraper still mounts the intended PVC and points at the intended database service name.

Useful app-level checks:

```bash
kubectl --context mars describe application csearch-mars-core -n argocd
kubectl --context mars describe application csearch-mars-scraper -n argocd
```

## 13. Recommended Order of Work

1. Treat the netcup names as the canonical resource names.
2. Remove `api-dev` and `redis-dev` from the intended end state for `mars`.
3. Update the `mars` frontend to target `http://csearch-api` instead of `http://api-dev`.
4. Standardize the frontend workload name to `csearch-frontend`.
5. Install ArgoCD on `mars`.
6. Add repo credentials to ArgoCD if the GitHub repo is private.
7. Create `k8s/overlays/mars/core`.
8. Normalize image tags to immutable SHA-based tags.
9. Create and sync `csearch-mars-core`.
10. Verify `csearch-api`, `csearch-redis`, `csearch-frontend`, and API-to-Postgres connectivity.
11. Decide how to reconcile the repo's dev DB and scraper manifests with the live `mars` resources.
12. Create `k8s/overlays/mars/scraper` only after that reconciliation.
13. Create and sync `csearch-mars-scraper`.
14. Move the image pull secret into a GitOps-safe secret workflow.
15. Optionally clean up dev DB credentials and broader manifest structure later.

## 14. Bottom Line

The fastest safe path is not a full `k8s/` rewrite. It is:

1. Standardize `mars` on the existing netcup names
2. Use those canonical names for the Argo-managed resources
3. Keep any `mars`-only LoadBalancer services separate and explicitly environment-specific
4. Deploy immutable image tags through Git commits
5. Bring the scraper and storage resources under ArgoCD only after the repo manifests are aligned with what is actually running on `mars`

That gives you a real GitOps deployment path for `mars` without mixing in the separate production S3/CloudFront flow or forcing a large manifest refactor up front.
