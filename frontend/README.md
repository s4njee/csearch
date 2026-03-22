# Frontend

The frontend is the user-facing CSearch application built with Nuxt 4 and Vue 3.

Its job is to:

- render bill, vote, committee, member, and explore pages
- fetch data from the CSearch API
- support both local development and Kubernetes-hosted or static-publish deployment paths

## Runtime Modes

This frontend has multiple runtime shapes, and they do not all resolve the API base URL the same way.

| Mode | Main use | Main files |
| --- | --- | --- |
| Local `nuxt dev` | development with hot reload | `package.json`, `nuxt.config.ts` |
| nginx container | cluster-hosted frontend deployments | `Dockerfile.nginx`, `docker-entrypoint.sh`, `k8s/netcup-test-frontend/` |
| Static site publish | public site publishing | `deploy.sh` |
| Deploy container | scheduled static publishing job | `Dockerfile.deploy`, `deploy-container.sh`, `k8s/frontend/deploy-cronjob.yaml` |

## API Base Resolution

The frontend resolves the API origin in this order:

1. `window.__CSEARCH_RUNTIME_CONFIG__.API_SERVER` from `runtime-config.js`
2. Nuxt public runtime config
3. the default `API_SERVER` value in `nuxt.config.ts`

Relevant files:

- `composables/useApiBase.ts`
- `composables/useCongressApi.ts`
- `public/runtime-config.js`
- `docker-entrypoint.sh`

This matters because nginx container deployments inject the runtime value at container startup.

## Key Files

| Path | Purpose |
| --- | --- |
| `pages/` | route-level pages |
| `components/` | shared Vue UI pieces |
| `composables/useCongressApi.ts` | frontend API client wrapper |
| `composables/useApiBase.ts` | resolves the active API base URL |
| `types/congress.ts` | shared TypeScript interfaces and bill constants |
| `nuxt.config.ts` | Nuxt config, route rules, prerender targets, default API server |
| `assets/css/main.css` | global styles |
| `deploy.sh` | static publish flow for the public site |
| `Dockerfile.nginx` | nginx image for cluster-hosted generated output |
| `Dockerfile.deploy` | deploy-container image for scheduled publishing |

## Common Edit Points

| File | Edit this when |
| --- | --- |
| `pages/bills/[category]/index.vue` | bill list UX, search, sorting, or pagination changes |
| `pages/bills/[category]/[congress]/[number].vue` | bill detail layout or bill sub-section changes |
| `pages/votes/index.vue` | vote list filtering or vote search UI changes |
| `pages/explore.vue` | explore UI or result presentation changes |
| `composables/useCongressApi.ts` | the frontend needs a new API method or path |
| `composables/useApiBase.ts` | deployed environments are using the wrong API |
| `types/congress.ts` | API response shapes changed |
| `docker-entrypoint.sh` | nginx container runtime injection needs to change |
| `nuxt.config.ts` | prerender behavior or default API config changed |

## Page Map

| Route area | Main file |
| --- | --- |
| Home | `pages/index.vue` |
| Bill list | `pages/bills/[category]/index.vue` |
| Bill detail | `pages/bills/[category]/[congress]/[number].vue` |
| Votes | `pages/votes/index.vue` and `pages/votes/[voteid].vue` |
| Committees | `pages/committees/index.vue` and `pages/committees/[code].vue` |
| Members | `pages/members/[bioguide_id].vue` |
| Explore | `pages/explore.vue` |

## Direct Development

Run directly with hot reload:

```bash
cd frontend
npm install
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```

Use this when:

- you want the fastest feedback loop
- the API is already running separately

## Deployment

Argo CD is the default Kubernetes deployment strategy for the frontend-side manifests in this repo.

### Default Argo-managed frontend

Current default frontend app:

- [`argo/applications/csearch-netcup-test-frontend.yaml`](../argo/applications/csearch-netcup-test-frontend.yaml)
- [`k8s/netcup-test-frontend/kustomization.yaml`](../k8s/netcup-test-frontend/kustomization.yaml)

This path deploys:

- the nginx frontend container
- the `csearch-frontend-test` service
- the `test.csearch.org` ingress

Important detail:

- the API origin for nginx deployments comes from `NUXT_API_SERVER` in the Kubernetes manifest, not from the built assets alone

### Build the nginx image manually

Run this from the repo root:

```bash
source .env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-frontend:latest" \
  -f frontend/Dockerfile.nginx \
  frontend
```

### Public static publish

The public site still uses a static publish flow:

```bash
cd frontend
bash deploy.sh
```

That flow:

1. loads `../.env.prod`
2. runs `npx nuxt generate`
3. writes a deploy timestamp to `.output/public/meta.json`
4. syncs `.output/public/` to S3
5. invalidates CloudFront

### Scheduled deploy container

There is also a deploy-container image for automated static publishing:

- image build file: `Dockerfile.deploy`
- runtime script: `deploy-container.sh`
- CronJob: `../k8s/frontend/deploy-cronjob.yaml`

## How To Make Common Changes

### Add a field to a page

1. confirm the API already returns the field
2. update `types/congress.ts` if needed
3. update the relevant page or component
4. verify the static-generation path still works

### Add a new page

1. add the page under `pages/`
2. add shared types or API methods if needed
3. if the page should be pre-rendered in static builds, update `nuxt.config.ts`

### Change how the frontend talks to the API

Start with:

- `composables/useApiBase.ts`
- `composables/useCongressApi.ts`
- `nuxt.config.ts`
- `docker-entrypoint.sh`
- the manifest or environment that sets `NUXT_API_SERVER`

## Troubleshooting

### The page works in `nuxt dev` but not in the nginx container

That usually means the runtime API target is different from the build-time API target. Check:

- `docker-entrypoint.sh`
- the manifest that sets `NUXT_API_SERVER`
- `useApiBase.ts`

### A page is missing from the generated output

Check `nuxt.config.ts`. Static generation only includes routes that are crawled or explicitly listed in the prerender config.

### Frontend data looks stale after a scraper run

Remember that scraper freshness and frontend freshness are not the same thing:

- the public site updates only after the static publish flow runs
- the Argo-managed frontend updates when its image or manifest changes in Git

### The deployed frontend uses the wrong API

Check:

- the value injected into `runtime-config.js`
- the `NUXT_API_SERVER` value in the relevant manifest or environment
- the fallback default in `nuxt.config.ts`
