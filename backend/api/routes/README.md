# API Routes

Each file in this directory registers one or more Fastify routes.

Use this folder for:

- request validation
- response shaping
- route-specific caching
- route-scoped logging

Keep business logic close to the route unless it is clearly reusable across multiple endpoints. Shared helpers should move to `services/`, `utils/`, or `plugins/`.

## Current Route Map

| File | Main responsibility |
| --- | --- |
| `root.js` | Root and health endpoints |
| `latestRoute.js` | Latest bill lists |
| `billRoute.js` | Bill detail |
| `billsByNumberRoute.js` | Bill lookup by number |
| `searchRoute.js` | Bill search |
| `latestVote.js` | Recent vote lists |
| `voteRoute.js` | Vote search and detail |
| `memberRoute.js` | Member detail |
| `committeeRoute.js` | Committee list and detail |
| `exploreRoute.js` | Explore query listing and execution |
| `adminRoute.js` | Cache reset endpoint |
| `authRoute.js` | Authentication and vote-tracking endpoints |

## Working Style

When adding or updating routes:

1. Validate input close to the route entry point
2. Keep SQL readable and explicit
3. Add structured request logs when the route does something operationally important
4. Add a test in `../test/routes/`

## Cache Convention

Routes that use the shared cache should set:

- `X-Cache: HIT` when served from cache
- `X-Cache: MISS` when served from Postgres

That makes cache behavior visible to both operators and the frontend.
