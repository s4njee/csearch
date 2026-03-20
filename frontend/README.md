# Frontend

Nuxt 4 powers the CSearch frontend. There are two deployment paths, and they intentionally behave differently.

## Production deploy

```bash
cd frontend
bash deploy.sh
```

This flow:

1. Sources `../.env.prod`
2. Builds the static site with `npx nuxt generate`
3. Uses `https://api.csearch.org` as the default production API origin
4. Syncs `.output/public/` to S3
5. Invalidates CloudFront

## Dev deploy on `mars`

The dev frontend runs as an nginx container on the `mars` k3s cluster instead of syncing to S3.

```bash
source ../.env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-frontend:latest" \
  -f Dockerfile.nginx \
  .

kubectl --context mars apply -f ../k8s/frontend/mars-deployment.yaml
kubectl --context mars apply -f ../k8s/frontend/dev-service.yaml
```

The `mars` deployment injects `NUXT_API_SERVER=http://192.168.1.156:3000` at runtime, so the dev API target lives in the manifest rather than being baked into the image.

## Local dev

```bash
cd frontend
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```
