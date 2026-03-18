const LRU = require("lru-cache");

// Global cache instance across all routes for this Fastify process
const cache = new LRU({
  max: 500, // accommodate up to 500 different route variations
  maxAge: 1000 * 60 * 60 * 24, // 24 hours TTL, intended to be manually cleared daily
});

module.exports = cache;
