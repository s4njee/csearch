# Argo CD Deployment Notes

This file documents the current Argo-first deployment layout in this repo.

For the consolidated deployment guide, see [`../deployment.md`](../deployment.md). For the high-level overview, see [`../../README.md`](../../README.md).

## Default Argo Applications

Argo CD is the default deployment strategy.

Current default applications:

| Application | Git path | Purpose | Sync wave |
| --- | --- | --- | --- |
| `csearch-netcup-db` | `k8s/netcup-db` | Postgres StatefulSet, services, and schema bootstrap | `-10` |
| `csearch-netcup-core` | `k8s/netcup-core` | API, Redis, and API ingress | `0` |
| `csearch-netcup-scraper` | `k8s/netcup-scraper` | scraper CronJob | `10` |
| `csearch-netcup-test-frontend` | `k8s/netcup-test-frontend` | standalone frontend for `test.csearch.org` | default |

Application manifests live under [`../../argo/applications/`](../../argo/applications/).

## Current Source Of Truth

### Argo applications

- [`../../argo/applications/csearch-netcup-db.yaml`](../../argo/applications/csearch-netcup-db.yaml)
- [`../../argo/applications/csearch-netcup-core.yaml`](../../argo/applications/csearch-netcup-core.yaml)
- [`../../argo/applications/csearch-netcup-scraper.yaml`](../../argo/applications/csearch-netcup-scraper.yaml)
- [`../../argo/applications/csearch-netcup-test-frontend.yaml`](../../argo/applications/csearch-netcup-test-frontend.yaml)

### Synced Kustomize roots

- [`../../k8s/netcup-db/kustomization.yaml`](../../k8s/netcup-db/kustomization.yaml)
- [`../../k8s/netcup-core/kustomization.yaml`](../../k8s/netcup-core/kustomization.yaml)
- [`../../k8s/netcup-scraper/kustomization.yaml`](../../k8s/netcup-scraper/kustomization.yaml)
- [`../../k8s/netcup-test-frontend/kustomization.yaml`](../../k8s/netcup-test-frontend/kustomization.yaml)

## How The Current Flow Works

1. a Git change lands in an Argo-managed manifest or in code that produces a new deployable image
2. the relevant manifests in Git point Argo at the desired state
3. Argo CD syncs the matching application and applies the change

Important detail:

- Argo reacts to Git state, not to registry updates alone
- if you rely on a new image tag, that tag change still needs to be represented in Git for Argo to act on it

## Current Branch Targets

The current netcup applications point at:

- `targetRevision: codex/claude`

That means the Git branch Argo watches must receive the manifest changes you expect it to deploy.

## Useful Commands

Install Argo CD into the cluster:

```bash
kubectl --context mars create namespace argocd
kubectl --context mars apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Inspect applications:

```bash
kubectl --context mars get applications -n argocd
kubectl --context mars describe application csearch-netcup-db -n argocd
kubectl --context mars describe application csearch-netcup-core -n argocd
kubectl --context mars describe application csearch-netcup-scraper -n argocd
kubectl --context mars describe application csearch-netcup-test-frontend -n argocd
```

Open the UI locally:

```bash
kubectl --context mars port-forward svc/argocd-server -n argocd 8080:443
```

Get the initial admin password:

```bash
kubectl --context mars -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

## Practical Change Checklist

When you change an Argo-managed environment:

1. update app code or the relevant `k8s/netcup-*` manifest
2. confirm the matching `Application` points at the branch you are changing
3. commit and push the Git change
4. confirm Argo syncs the application
5. verify the resulting pods, services, ingress, or CronJob in Kubernetes
