# Deployment Guide

Argo CD is the default deployment strategy for CSearch. This document covers the Argo-managed deployment flow, the current application layout, and operational commands.

For the high-level architecture, see [`ARCHITECTURE.md`](../ARCHITECTURE.md). For caching details, see [`caching.md`](caching.md).

## Argo Applications

| Application | Git path | Purpose | Sync wave |
| --- | --- | --- | --- |
| `csearch-netcup-db` | `k8s/netcup-db` | Postgres StatefulSet, services, and schema bootstrap | `-10` |
| `csearch-netcup-core` | `k8s/netcup-core` | API, Redis, and API ingress | `0` |
| `csearch-netcup-scraper` | `k8s/netcup-scraper` | Scraper CronJob | `10` |
| `csearch-netcup-test-frontend` | `k8s/netcup-test-frontend` | Standalone frontend for `test.csearch.org` | default |

Application manifests live under [`argo/applications/`](../argo/applications/).

Synced Kustomize roots:

- [`k8s/netcup-db/kustomization.yaml`](../k8s/netcup-db/kustomization.yaml)
- [`k8s/netcup-core/kustomization.yaml`](../k8s/netcup-core/kustomization.yaml)
- [`k8s/netcup-scraper/kustomization.yaml`](../k8s/netcup-scraper/kustomization.yaml)
- [`k8s/netcup-test-frontend/kustomization.yaml`](../k8s/netcup-test-frontend/kustomization.yaml)

## How Deployment Works

1. Change app code or the relevant Argo-managed manifest
2. Commit and push the Git change
3. Argo CD syncs the matching application from Git

Argo reacts to Git state, not to registry updates alone. If you rely on a new image tag, that tag change still needs to be represented in Git for Argo to act on it.

The current netcup applications point at `targetRevision: codex/claude`, so manifest changes must land on that branch for Argo to deploy them.

## Image Build Commands

### Scraper

Run from the repo root (the Dockerfile uses root-relative paths):

```bash
source .env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-updater:latest" \
  -f backend/scraper/Dockerfile .
```

### API

Run from the repo root so you can sync the explore SQL source:

```bash
source .env.prod
mkdir -p backend/api/sql
cp backend/scraper/explore.sql backend/api/sql/explore.sql

cd backend/api
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-api:latest" .
```

### Frontend (nginx)

```bash
source .env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-frontend:latest" \
  -f frontend/Dockerfile.nginx \
  frontend
```

## Static Site Publishing

The public site uses a separate static publish flow, not Argo:

```bash
cd frontend
bash deploy.sh
```

That script sources `../.env.prod`, runs `npx nuxt generate`, syncs `.output/public` to S3, and invalidates CloudFront. A completed scraper run does not automatically refresh the public static site.

## CI/CD

The workflow at `.github/workflows/mars-images.yml` automates image builds and tag updates for the frontend-oriented path. Argo itself is the default deployment mechanism — the Git change is the deploy trigger.

## Useful Argo Commands

Inspect applications:

```bash
kubectl --context mars get applications -n argocd
kubectl --context mars describe application csearch-netcup-db -n argocd
kubectl --context mars describe application csearch-netcup-core -n argocd
kubectl --context mars describe application csearch-netcup-scraper -n argocd
kubectl --context mars describe application csearch-netcup-test-frontend -n argocd
```

Open the Argo UI locally:

```bash
kubectl --context mars port-forward svc/argocd-server -n argocd 8080:443
```

Get the initial admin password:

```bash
kubectl --context mars -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Install Argo CD into the cluster (first-time setup):

```bash
kubectl --context mars create namespace argocd
kubectl --context mars apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Useful Kubectl Commands

```bash
# Check running pods
kubectl get pods

# Trigger a manual scraper run
kubectl create job csearch-updater-manual-$(date +%s) --from=cronjob/csearch-updater

# Tail scraper job logs
kubectl logs -f job/<job-name>

# Restart the API deployment after an image push
kubectl rollout restart deployment/csearch-api
kubectl rollout status deployment/csearch-api
```

## Change Checklist

When you change an Argo-managed environment:

1. Update app code or the relevant `k8s/netcup-*` manifest
2. Confirm the matching `Application` points at the branch you are changing
3. Commit and push the Git change
4. Confirm Argo syncs the application
5. Verify the resulting pods, services, ingress, or CronJob in Kubernetes

## Cluster Details

- **Registry**: `$REGISTRY` (set in `.env.prod`)
- **Server**: `$CLUSTER_HOST` (set in `.env.prod`)
- **Namespace**: `default`
- **Congress data on host**: `/root/congress/`
- **kubectl context**: `mars`
