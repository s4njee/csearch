"use strict";

const Redis = require("ioredis");

const TTL_SECONDS = 60 * 60 * 24;
const KEY_PREFIX = "csearch:";

const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379", {
  enableOfflineQueue: false,
  lazyConnect: false,
  maxRetriesPerRequest: 1,
  retryStrategy(times) {
    return Math.min(times * 200, 5000);
  },
});

let connected = false;
let closed = false;

redis.on("connect", () => {
  connected = true;
  closed = false;
});

redis.on("error", (err) => {
  connected = false;

  if (err.code !== "ECONNREFUSED" && err.code !== "ECONNRESET") {
    console.error("redis error:", err.message);
  }
});

redis.on("close", () => {
  connected = false;
});

redis.on("end", () => {
  connected = false;
  closed = true;
});

module.exports = {
  async get(key) {
    if (!connected || closed) return undefined;

    try {
      const raw = await redis.get(KEY_PREFIX + key);
      return raw ? JSON.parse(raw) : undefined;
    } catch {
      return undefined;
    }
  },

  async set(key, value) {
    if (!connected || closed) return;

    try {
      await redis.set(KEY_PREFIX + key, JSON.stringify(value), "EX", TTL_SECONDS);
    } catch {
      // Cache failures should never break the request path.
    }
  },

  async reset() {
    if (!connected || closed) return;

    const stream = redis.scanStream({ match: KEY_PREFIX + "*", count: 100 });
    const pipeline = redis.pipeline();
    let count = 0;

    for await (const keys of stream) {
      for (const key of keys) {
        pipeline.del(key);
        count += 1;
      }
    }

    if (count > 0) {
      await pipeline.exec();
    }
  },

  async quit() {
    if (closed) return;

    try {
      await redis.quit();
    } catch {
      redis.disconnect();
    } finally {
      connected = false;
      closed = true;
    }
  },

  get isConnected() {
    return connected;
  },
};
