# API Plugins

Files in this directory register reusable Fastify behavior that is shared across routes.

Use plugins when the behavior is cross-cutting rather than route-specific, for example:

- authentication helpers
- decorators
- shared lifecycle hooks
- support utilities needed across the app

## Current Plugins

| File | Purpose |
| --- | --- |
| `auth.js` | JWT support and auth-related helpers |
| `sensible.js` | Fastify sensible plugin registration |
| `support.js` | Shared support behavior from the Fastify scaffold |

## When To Add A Plugin

Add a plugin when the functionality:

- is used by multiple routes
- benefits from Fastify decorators or hooks
- is cleaner as app-wide setup than inline route code

If the code is only used by one route, keep it near that route instead of creating a plugin too early.
