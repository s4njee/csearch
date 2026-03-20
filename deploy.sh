#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env.prod"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy .env.prod.example to .env.prod and fill in values." >&2
  exit 1
fi
# shellcheck source=.env.prod
source "$ENV_FILE"

KUBECTL="kubectl --context=${KUBECTL_CONTEXT}"
REGISTRY="${REGISTRY:-registry.s8njee.com}"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
VCS_REF="$(git rev-parse --short HEAD)"

# Parse flags
SKIP_SCRAPER=false
for arg in "$@"; do
  case "$arg" in
    --skip-scraper) SKIP_SCRAPER=true ;;
  esac
done

echo "==> Using kubectl context: ${KUBECTL_CONTEXT}"
echo "==> Registry: ${REGISTRY}"
echo "==> Skip scraper: ${SKIP_SCRAPER}"

# ---------------------------------------------------------------------------
# 0. Build and push Docker images (linux/amd64)
# ---------------------------------------------------------------------------
echo ""
echo "==> Building csearch-postgres (linux/amd64)..."
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t "${REGISTRY}/csearch-postgres:latest" \
  -f k8s/db/Dockerfile \
  .

echo ""
echo "==> Building csearch-api (linux/amd64)..."
mkdir -p backend/api/sql
cp backend/scraper/explore.sql backend/api/sql/explore.sql
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t "${REGISTRY}/csearch-api:latest" \
  -t "${REGISTRY}/csearch-api:${VCS_REF}" \
  backend/api

if [[ "$SKIP_SCRAPER" == "false" ]]; then
  echo ""
  echo "==> Building csearch-updater (linux/amd64)..."
  docker buildx build \
    --platform linux/amd64 \
    --push \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg VCS_REF="${VCS_REF}" \
    -t "${REGISTRY}/csearch-updater:latest" \
    -t "${REGISTRY}/csearch-updater:${VCS_REF}" \
    -f backend/scraper/Dockerfile \
    .
else
  echo ""
  echo "==> Skipping csearch-updater build."
fi

echo ""
echo "==> Building csearch-frontend (linux/amd64)..."
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t "${REGISTRY}/csearch-frontend:latest" \
  -t "${REGISTRY}/csearch-frontend:${VCS_REF}" \
  -f frontend/Dockerfile.deploy \
  frontend

# ---------------------------------------------------------------------------
# Registry pull secret
# ---------------------------------------------------------------------------
if ! ${KUBECTL} get secret registry-s8njee-pull &>/dev/null; then
  echo ""
  echo "WARNING: Secret 'registry-s8njee-pull' not found on cluster."
  echo "  Fill in k8s/registry-pull-secret.yaml with real registry credentials,"
  echo "  then run:"
  echo "    kubectl --context=${KUBECTL_CONTEXT} apply -f k8s/registry-pull-secret.yaml"
  echo ""
  read -r -p "Continue deployment anyway? (y/N) " confirm
  [[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

# ---------------------------------------------------------------------------
# 1. Database – config/secret must come before the StatefulSet
# ---------------------------------------------------------------------------
echo ""
echo "==> Applying database config and secrets..."
envsubst < k8s/db/config.yaml | ${KUBECTL} apply -f -
${KUBECTL} create configmap postgres-schema \
  --from-file=001-schema.sql=backend/scraper/schema.sql \
  --dry-run=client -o yaml | ${KUBECTL} apply -f -

echo "==> Applying database deployment and service..."
${KUBECTL} apply -f k8s/db/statefulset.yaml
${KUBECTL} apply -f k8s/db/service.yaml

echo "==> Waiting for postgres to be ready..."
${KUBECTL} rollout status statefulset/postgres --timeout=120s

# ---------------------------------------------------------------------------
# 2. API
# ---------------------------------------------------------------------------
echo ""
echo "==> Applying API deployment..."
envsubst < k8s/api/deployment.yaml | ${KUBECTL} apply -f -

echo "==> Restarting API pods to pick up new image..."
${KUBECTL} rollout restart deployment/csearch-api

echo "==> Waiting for API to be ready..."
${KUBECTL} rollout status deployment/csearch-api --timeout=120s

# ---------------------------------------------------------------------------
# 3. Scraper CronJob
# ---------------------------------------------------------------------------
if [[ "$SKIP_SCRAPER" == "false" ]]; then
  echo ""
  echo "==> Applying scraper CronJob..."
  ${KUBECTL} apply -f k8s/scraper/cronjob.yaml
else
  echo ""
  echo "==> Skipping scraper k8s resources."
fi

# ---------------------------------------------------------------------------
# 4. Logging shipping
# ---------------------------------------------------------------------------
if [[ -n "${LOG_SHIP_HTTP_HOST:-}" ]]; then
  echo ""
  echo "==> Applying Fluent Bit logging stack..."
  envsubst < k8s/logging/fluent-bit-config.yaml | ${KUBECTL} apply -f -
  ${KUBECTL} apply -f k8s/logging/fluent-bit-rbac.yaml
  envsubst < k8s/logging/fluent-bit-daemonset.yaml | ${KUBECTL} apply -f -

  echo "==> Waiting for Fluent Bit DaemonSet rollout..."
  ${KUBECTL} rollout status daemonset/csearch-fluent-bit --timeout=120s
else
  echo ""
  echo "==> Skipping Fluent Bit logging stack (LOG_SHIP_HTTP_HOST is unset)."
fi

# ---------------------------------------------------------------------------
# 5. Frontend – Nuxt static build → S3 + CloudFront
# ---------------------------------------------------------------------------
echo ""
echo "==> Applying frontend RBAC..."
${KUBECTL} apply -f k8s/frontend/rbac.yaml

echo ""
echo "==> Deploying frontend..."
bash frontend/deploy.sh

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Deployment complete. Current resource status:"
${KUBECTL} get statefulset,deployment,cronjob,service,pvc
