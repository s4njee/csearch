# Deployment Notes

The deployment source of truth is [`../DEPLOY.md`](../DEPLOY.md).

Use this file only as a local pointer from older links. Current deployment
paths are:

- Cloudflare Pages for the public Nuxt site through
  [`../frontend/deploy.sh`](../frontend/deploy.sh) and
  [`.github/workflows/frontend-cloudflare-deploy.yml`](../.github/workflows/frontend-cloudflare-deploy.yml)
- Argo CD applications under [`../argo/applications/`](../argo/applications/)
  for Kubernetes workloads
- Active Kubernetes roots under [`../k8s/netcup-*`](../k8s/) and
  [`../k8s/freya-*`](../k8s/)

Legacy root deploy scripts and legacy Kubernetes manifests were removed from
the active tree. Recover them from git history only when doing archaeology.
