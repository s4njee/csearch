#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${REPO_ROOT}/.env.prod"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

REGISTRY="${REGISTRY:-registry.s8njee.com}"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
VCS_REF="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"

echo "==> Building csearch-updater"
echo "==> Registry: ${REGISTRY}"
echo "==> VCS ref: ${VCS_REF}"

cd "${REPO_ROOT}"

docker buildx build \
  --platform linux/amd64 \
  --push \
  --build-arg BUILD_DATE="${BUILD_DATE}" \
  --build-arg VCS_REF="${VCS_REF}" \
  -t "${REGISTRY}/csearch-updater:latest" \
  -t "${REGISTRY}/csearch-updater:${VCS_REF}" \
  -f backend/scraper/Dockerfile \
  .
