# Redis Cache Migration Plan

## Context

The Fastify API uses an in-memory `lru-cache` (500 entries, 24h TTL) in `backend/api/utils/cache.js`. With 2 K8s replicas each pod maintains its own isolated cache, meaning:
- Cache clears via `/admin/clear-cache` only affect the pod that receives the request
- Cache warming is duplicated across pods
- Pod restarts lose all cached data

Migrating to Redis provides a shared cache across all replicas, consistent cache clears, and better scalability.

## Architecture Decision

- **Library:** `ioredis` (auto-reconnect, no `.connect()` needed, battle-tested)
- **Degradation:** If Redis is down, API continues to work uncached (no errors, just misses)
- **Key prefix:** `csearch:` to namespace keys
- **TTL:** 24 hours (matches current LRU config)
- **Eviction:** Redis `allkeys-lru` (mirrors current in-memory LRU behavior)

---

## Step 1: Add `ioredis` dependency

**File:** `backend/api/package.json`

Add to the `dependencies` object:
```
"ioredis": "^5.3.0"
```

Remove these two entries (no longer needed):
```
"lru-cache": "^6.0.0"
"tiny-lru": "^10.0.1"
"yallist": "^4.0.0"
```

Then run:
```bash
cd backend/api && npm install
```

---

## Step 2: Rewrite the cache module

**File:** `backend/api/utils/cache.js`

Replace the entire file contents with:

```javascript
"use strict";

const Redis = require("ioredis");

const TTL_SECONDS = 60 * 60 * 24; // 24 hours
const KEY_PREFIX = "csearch:";

const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379", {
  maxRetriesPerRequest: 1,
  retryStrategy(times) {
    return Math.min(times * 200, 5000);
  },
  lazyConnect: false,
});

let connected = false;

redis.on("connect", () => {
  connected = true;
});

redis.on("error", (err) => {
  connected = false;
  // ioredis logs reconnection attempts internally; only surface unexpected errors
  if (err.code !== "ECONNREFUSED" && err.code !== "ECONNRESET") {
    console.error("redis error:", err.message);
  }
});

redis.on("close", () => {
  connected = false;
});

module.exports = {
  /**
   * Get a cached value by key. Returns undefined on miss or error.
   */
  async get(key) {
    if (!connected) return undefined;
    try {
      const raw = await redis.get(KEY_PREFIX + key);
      return raw ? JSON.parse(raw) : undefined;
    } catch {
      return undefined;
    }
  },

  /**
   * Set a cached value with the standard TTL. Silently fails if Redis is down.
   */
  async set(key, value) {
    if (!connected) return;
    try {
      await redis.set(KEY_PREFIX + key, JSON.stringify(value), "EX", TTL_SECONDS);
    } catch {
      // swallow — cache is non-critical
    }
  },

  /**
   * Delete all csearch:-prefixed keys using SCAN (non-blocking, safe for shared Redis).
   */
  async reset() {
    if (!connected) return;
    const stream = redis.scanStream({ match: KEY_PREFIX + "*", count: 100 });
    const pipeline = redis.pipeline();
    let count = 0;
    for await (const keys of stream) {
      for (const k of keys) {
        pipeline.del(k);
        count++;
      }
    }
    if (count > 0) await pipeline.exec();
  },

  /**
   * Cleanly close the Redis connection (for graceful shutdown).
   */
  async quit() {
    await redis.quit();
  },

  /** Expose connection state for health checks. */
  get isConnected() {
    return connected;
  },
};
```

### Why these choices

- `maxRetriesPerRequest: 1` — prevents a downed Redis from stalling HTTP requests behind multi-second retry loops
- `JSON.stringify`/`JSON.parse` — all cached values are already JSON-serializable objects
- `SCAN` + pipeline `DEL` in `reset()` — avoids `FLUSHDB` so this is safe if other apps ever share the Redis instance
- Every method returns a safe fallback (`undefined`) on error so routes fall through to the database

---

## Step 3: Update route files

The cache interface is now async. All route handlers are already `async` so only `await` keywords need adding. Also, collapse the `has()` + `get()` two-call pattern into a single `get()` to eliminate one Redis round-trip per cache hit.

### 3a. `backend/api/routes/latestRoute.js`

**Lines 14-18** — replace:
```javascript
    const cacheKey = `latest_bills_${billtype}`;
    if (cache.has(cacheKey)) {
      reply.header("X-Cache", "HIT");
      return cache.get(cacheKey);
    }
```
with:
```javascript
    const cacheKey = `latest_bills_${billtype}`;
    const cached = await cache.get(cacheKey);
    if (cached !== undefined) {
      reply.header("X-Cache", "HIT");
      return cached;
    }
```

**Line 43** — replace:
```javascript
    cache.set(cacheKey, data);
```
with:
```javascript
    await cache.set(cacheKey, data);
```

### 3b. `backend/api/routes/latestVote.js`

**Lines 15-19** — replace:
```javascript
    const cacheKey = `latest_votes_${chamber}`;
    if (cache.has(cacheKey)) {
      reply.header("X-Cache", "HIT");
      return cache.get(cacheKey);
    }
```
with:
```javascript
    const cacheKey = `latest_votes_${chamber}`;
    const cached = await cache.get(cacheKey);
    if (cached !== undefined) {
      reply.header("X-Cache", "HIT");
      return cached;
    }
```

**Line 42** — replace:
```javascript
    cache.set(cacheKey, data);
```
with:
```javascript
    await cache.set(cacheKey, data);
```

### 3c. `backend/api/routes/exploreRoute.js`

**Lines 26-29** — replace:
```javascript
    if (cache.has(cacheKey)) {
      reply.header("X-Cache", "HIT");
      return cache.get(cacheKey);
    }
```
with:
```javascript
    const cached = await cache.get(cacheKey);
    if (cached !== undefined) {
      reply.header("X-Cache", "HIT");
      return cached;
    }
```

**Line 52** — replace:
```javascript
    cache.set(cacheKey, response);
```
with:
```javascript
    await cache.set(cacheKey, response);
```

### 3d. `backend/api/routes/adminRoute.js`

**Line 14** — replace:
```javascript
    cache.reset();
```
with:
```javascript
    await cache.reset();
```

**Line 16** — update the message:
```javascript
    return { success: true, message: "Cache successfully reset" };
```

---

## Step 4: Add Redis graceful shutdown

**File:** `backend/api/app.js`

At the top of the `module.exports` function (around line 13), add the cache import alongside the existing `db` import pattern. Then update the `onClose` hook.

**Change the onClose hook (lines 58-64)** from:
```javascript
  const db = require('./controllers/db');
  fastify.addHook('onClose', async (instance) => {
    await db.knex.destroy();
  });
```
to:
```javascript
  const db = require('./controllers/db');
  const cache = require('./utils/cache');
  fastify.addHook('onClose', async (instance) => {
    await cache.quit();
    await db.knex.destroy();
  });
```

---

## Step 5: Add Redis to Docker Compose

**File:** `docker-compose.yml`

Add a `redis` service before the `api` service:
```yaml
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10
```

Update the `api` service — add redis to `depends_on` and add `REDIS_URL` env var:
```yaml
  api:
    build:
      context: ./backend/api
      dockerfile: Dockerfile
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      HOST: 0.0.0.0
      PORT: 3000
      POSTGRESURI: postgres
      SECRET_KEY: ${SECRET_KEY:-change-me-local-api-secret}
      REDIS_URL: redis://redis:6379
    expose:
      - "3000"
```

---

## Step 6: Add Redis to Kubernetes

### 6a. Create Redis deployment

**New file:** `k8s/redis/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csearch-redis
  labels:
    app.kubernetes.io/name: csearch-redis
    app.kubernetes.io/component: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: csearch-redis
  template:
    metadata:
      labels:
        app.kubernetes.io/name: csearch-redis
        app.kubernetes.io/component: cache
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: redis
          image: redis:7-alpine
          command:
            - redis-server
            - --maxmemory
            - 128mb
            - --maxmemory-policy
            - allkeys-lru
          ports:
            - name: redis
              containerPort: 6379
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 10
          livenessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 20
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 192Mi
---
apiVersion: v1
kind: Service
metadata:
  name: csearch-redis
  labels:
    app.kubernetes.io/name: csearch-redis
spec:
  selector:
    app.kubernetes.io/name: csearch-redis
  ports:
    - name: redis
      port: 6379
      targetPort: redis
  type: ClusterIP
```

### 6b. Add REDIS_URL to API deployment

**File:** `k8s/api/deployment.yaml`

Add this env var after the existing `PORT` entry (after line 55):
```yaml
            - name: REDIS_URL
              value: "redis://csearch-redis:6379"
```

---

## Step 7: Run `npm install` to update lockfile

```bash
cd backend/api && npm install
```

This removes `lru-cache` and `yallist` from node_modules and adds `ioredis`.

---

## Verification Checklist

1. **Cache HIT/MISS**: `docker-compose up` → `curl localhost:3000/latest/hr` returns `X-Cache: MISS`, second call returns `X-Cache: HIT`
2. **Redis degradation**: `docker-compose stop redis` → API still serves requests (every call is `X-Cache: MISS`, no 500 errors)
3. **Cache clear**: `curl -X POST -H "Authorization: $SECRET_KEY" localhost:3000/admin/clear-cache` → subsequent GETs return `X-Cache: MISS`
4. **Key inspection**: `docker-compose exec redis redis-cli KEYS "csearch:*"` → shows prefixed keys after hitting endpoints
5. **Graceful shutdown**: `docker-compose stop api` → no error logs from Redis connection

---

## Files Modified (Summary)

| File | Action |
|------|--------|
| `backend/api/package.json` | Add `ioredis`, remove `lru-cache`/`tiny-lru`/`yallist` |
| `backend/api/utils/cache.js` | Full rewrite (LRU → Redis) |
| `backend/api/routes/latestRoute.js` | Add `await` to cache calls |
| `backend/api/routes/latestVote.js` | Add `await` to cache calls |
| `backend/api/routes/exploreRoute.js` | Add `await` to cache calls |
| `backend/api/routes/adminRoute.js` | Add `await` to cache reset |
| `backend/api/app.js` | Add `cache.quit()` to onClose hook |
| `docker-compose.yml` | Add redis service + env var |
| `k8s/redis/deployment.yaml` | **New** — Redis Deployment + Service |
| `k8s/api/deployment.yaml` | Add `REDIS_URL` env var |
