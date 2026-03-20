#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/../.env.prod"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy .env.prod.example to .env.prod and fill in values." >&2
  exit 1
fi
# shellcheck source=../.env.prod
source "$ENV_FILE"

echo "==> Building..."
NUXT_API_SERVER="$NUXT_API_SERVER" npx nuxt generate

echo "==> Writing deploy timestamp..."
echo "{\"updated_at\": \"$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)\"}" > .output/public/meta.json

echo "==> Syncing to S3..."
aws s3 sync .output/public/ "$S3_BUCKET" --delete

echo "==> Invalidating CloudFront..."
aws cloudfront create-invalidation \
  --distribution-id "$CF_DIST_CSEARCH" \
  --paths "/*" \
  --query "Invalidation.{Id:Id,Status:Status}" \
  --output table

echo "==> Done."
