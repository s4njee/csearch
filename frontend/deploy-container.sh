#!/usr/bin/env bash
set -euo pipefail

cd /app


echo "==> Rolling restart of csearch-api to flush in-memory cache on all pods..."
kubectl rollout restart deployment/csearch-api
kubectl rollout status deployment/csearch-api --timeout=120s

echo "==> Building Nuxt for static generation..."
npx nuxt generate

echo "==> Writing deploy timestamp..."
echo "{\"updated_at\": \"$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)\"}" > .output/public/meta.json

echo "==> Syncing to S3 Bucket: ${S3_BUCKET}..."
aws s3 sync .output/public/ "${S3_BUCKET}" --delete

echo "==> Invalidating CloudFront Cache for Distribution ID: ${CF_DIST_CSEARCH}..."
aws cloudfront create-invalidation \
  --distribution-id "${CF_DIST_CSEARCH}" \
  --paths "/*" \
  --query "Invalidation.{Id:Id,Status:Status}" \
  --output table

echo "==> Deploy Successful!"
