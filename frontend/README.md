# Frontend

The frontend is the user-facing CSearch application built with Nuxt 4 and Vue 3.

Its job is to:

- render bill, vote, committee, member, and explore pages
- fetch data from the CSearch API
- support both static production builds and nginx-based cluster deployments

## What Makes This Frontend Slightly Unusual

This project has multiple runtime modes, and they do not all resolve the API base URL the same way.

The frontend can run as:

| Mode | Main use | Main files |
| --- | --- | --- |
| Local `nuxt dev` | development | `package.json`, `nuxt.config.ts` |
| Production static site | S3 + CloudFront deploy | `deploy.sh` |
| nginx container | cluster-hosted frontend deployments | `Dockerfile.nginx`, `docker-entrypoint.sh`, `k8s/frontend/*.yaml` |
| Deploy container | scheduled static publish job | `Dockerfile.deploy`, `deploy-container.sh`, `k8s/frontend/deploy-cronjob.yaml` |

If you are debugging “wrong API target” issues, always identify which of those modes you are in first.

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

This matters because:

- local `nuxt dev` often uses a build-time or dev-time value
- nginx container deployments inject the runtime value at container startup

## Key Files

| Path | Purpose |
| --- | --- |
| `pages/` | Route-level pages |
| `components/` | Shared Vue UI pieces |
| `composables/useCongressApi.ts` | API client wrapper used by pages and components |
| `composables/useApiBase.ts` | Resolves the API base URL |
| `types/congress.ts` | Shared frontend data types and bill constants |
| `nuxt.config.ts` | Nuxt configuration, route rules, prerender targets, default API server |
| `assets/css/main.css` | Global styles |
| `deploy.sh` | Production S3 + CloudFront deploy |
| `Dockerfile.nginx` | nginx image for cluster-hosted generated output |
| `Dockerfile.deploy` | deploy-container image for scheduled publish jobs |

## Most Used Files

These are the files engineers usually touch when making day-to-day frontend changes.

### `pages/bills/[category]/index.vue`

What it does:

- renders the main bill listing experience
- handles bill search, sorting, and pagination behavior

Edit this when:

- list-page UX changes
- bill search interaction changes
- list-level data presentation changes

### `pages/bills/[category]/[congress]/[number].vue`

What it does:

- renders the bill detail page
- consumes the bill detail API payload and related sub-sections

Edit this when:

- the bill detail page layout changes
- a new bill field needs to appear on the page
- bill-related sub-sections like actions or cosponsors change

### `pages/votes/index.vue`

What it does:

- renders the vote browsing and vote search entry point

Edit this when:

- vote list filtering changes
- vote search UI changes
- vote summary presentation changes

### `pages/explore.vue`

What it does:

- renders the analytical explore interface
- drives query selection and result display for explore SQL queries

Edit this when:

- the explore UI changes
- new query controls or result presentations are needed

### `composables/useCongressApi.ts`

What it does:

- provides the frontend’s typed wrapper around API calls
- centralizes endpoint path construction

Edit this when:

- the frontend needs a new API method
- an endpoint path changes
- request parameter construction changes

### `composables/useApiBase.ts`

What it does:

- resolves the active API base URL at runtime
- prefers runtime-injected config over the build-time default

Edit this when:

- deployed environments use the wrong API
- runtime versus build-time API behavior needs to change

### `types/congress.ts`

What it does:

- defines shared TypeScript interfaces and constants used across pages and components

Edit this when:

- API response shapes change
- new typed frontend data models are needed

### `components/BillsContainer.vue`

What it does:

- holds shared bill-list presentation logic used by list-style pages

Edit this when:

- reusable bill-card or list rendering behavior changes
- multiple bill-list pages need the same UI update

### `components/VotesContainer.vue`

What it does:

- holds shared vote-list rendering behavior

Edit this when:

- multiple vote views need the same rendering or filtering update

### `nuxt.config.ts`

What it does:

- defines Nuxt runtime config
- sets the default API server
- configures route rules and static prerender targets

Edit this when:

- prerendered routes change
- default API configuration changes
- dev proxy or global Nuxt behavior changes

### `deploy.sh`

What it does:

- runs the production static-site generation flow
- syncs the generated output to S3
- invalidates CloudFront

Edit this when:

- the production publish workflow changes
- deploy metadata changes
- the S3 or CloudFront deployment steps change

### `docker-entrypoint.sh`

What it does:

- writes `runtime-config.js` inside the nginx container at startup
- injects `NUXT_API_SERVER` without rebuilding the image

Edit this when:

- containerized deployments need different runtime API injection behavior
- the nginx-served frontend points at the wrong API

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

## Local Development

### Run the frontend with the full local stack

```bash
docker-compose up --build
```

In this mode:

- the frontend is served at [http://localhost:8080](http://localhost:8080)
- `NUXT_API_SERVER=/api`
- Nuxt proxies `/api/**` to the API container

This is the easiest way to work end to end.

### Run the frontend directly with hot reload

```bash
cd frontend
npm install
NUXT_API_SERVER=http://localhost:3000 npx nuxt dev
```

Use this when:

- you want the fastest feedback loop
- the API is already running separately

## Production Deploy

Run from `frontend/`:

```bash
bash deploy.sh
```

This flow:

1. loads `../.env.prod`
2. runs `npx nuxt generate`
3. writes a deploy timestamp to `.output/public/meta.json`
4. syncs `.output/public/` to S3
5. invalidates CloudFront

The production API origin is provided by `NUXT_API_SERVER` from `.env.prod`.

## Cluster-Hosted nginx Deploy

For environments where the frontend is served from a container instead of S3:

```bash
source ../.env.prod
docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-api:redis" \
  ../backend/api

docker buildx build --platform linux/amd64 --push \
  -t "$REGISTRY/csearch-frontend:latest" \
  -f Dockerfile.nginx \
  .

kubectl --context mars apply -f ../k8s/dev/api.yaml
kubectl --context mars apply -f ../k8s/frontend/mars-deployment.yaml
kubectl --context mars apply -f ../k8s/frontend/dev-service.yaml
```

Important behavior:

- the site is generated during the image build
- `docker-entrypoint.sh` writes `runtime-config.js` at container startup
- the manifest sets `NUXT_API_SERVER`, which overrides the build-time default
- on `mars`, the frontend points to the in-cluster `api-dev` service, not the API load balancer IP
- on `mars`, `../k8s/dev/api.yaml` deploys both `api-dev` and `redis-dev`, and the API image is currently pinned to `registry.s8njee.com/csearch-api:redis`

## Scheduled Deploy Container

There is a second frontend container image used for automated static publishing:

- image build file: `Dockerfile.deploy`
- runtime script: `deploy-container.sh`
- CronJob: `../k8s/frontend/deploy-cronjob.yaml`

That container:

1. restarts the API deployment to clear process-local cache
2. runs `nuxt generate`
3. publishes the static output to S3
4. invalidates CloudFront

This is separate from the nginx runtime image used for cluster-hosted page serving.

## How To Make Common Changes

### Add a field to a page

1. Confirm the API already returns the field
2. Update `types/congress.ts` if needed
3. Update the relevant page or component
4. Verify the static-generation path still works

### Add a new page

1. Add the page under `pages/`
2. Add shared types or API methods if needed
3. If the page should be pre-rendered in static builds, update `nuxt.config.ts`

### Change how the frontend talks to the API

Start with:

- `composables/useApiBase.ts`
- `composables/useCongressApi.ts`
- `nuxt.config.ts`
- `docker-entrypoint.sh`

## Troubleshooting

### The page works in `nuxt dev` but not in the nginx container

That usually means the runtime API target is different from the build-time API target. Check:

- `docker-entrypoint.sh`
- the manifest that sets `NUXT_API_SERVER`
- `useApiBase.ts`

### A page is missing from the generated output

Check `nuxt.config.ts`. Static generation only includes the routes that are crawled or explicitly listed in the prerender config.

### Frontend data looks stale after a scraper run

Remember that the public site updates only after the frontend generation and publish flow runs. Scraper freshness and frontend freshness are related but not identical.
