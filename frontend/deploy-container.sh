#!/usr/bin/env bash
set -euo pipefail

cd /app


echo "==> Rolling restart of csearch-api before publishing frontend..."
kubectl rollout restart deployment/csearch-api
kubectl rollout status deployment/csearch-api --timeout=120s

echo "==> Building Nuxt for static generation..."
NUXT_API_SERVER="${NUXT_API_SERVER:-https://api.csearch.org}" npm run generate

echo "==> Writing deploy timestamp..."
echo "{\"updated_at\": \"$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)\"}" > .output/public/meta.json

echo "==> Deploying to Cloudflare Pages project: ${CF_PAGES_PROJECT:-csearch}..."
npx wrangler pages deploy .output/public --project-name "${CF_PAGES_PROJECT:-csearch}" --branch "${CF_PAGES_BRANCH:-main}"

echo "==> Deploy Successful!"
