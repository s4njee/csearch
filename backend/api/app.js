"use strict";

const path = require("path");
const AutoLoad = require("@fastify/autoload");
const cors = require("@fastify/cors");

// Fastify options: trustProxy ensures we get real user IPs behind CloudFront/K8s
// instead of blocking EVERYONE as 1 IP through the rate limiter!
module.exports.options = {
  trustProxy: true
};

module.exports = async function (fastify, opts) {
  // Place here your custom code!

  // Do not touch the following lines

  // This loads all plugins defined in plugins
  // those should be support plugins that are reused
  fastify.register(cors, {
    // put your options here
  });

  fastify.register(require('@fastify/compress'), {
    global: true,
    encodings: ['br', 'gzip'] // Brotli prioritized
  });

  // 1. API Rate Limiting to protect heavy PostgreSQL CPU queries
  fastify.register(require('@fastify/rate-limit'), {
    max: 100, // Limit each IP to 100 requests per time window
    timeWindow: '1 minute'
  });

  // Record one structured line per completed request so latency and cache
  // behavior can be queried directly from stdout logs.
  fastify.addHook('onResponse', (request, reply, done) => {
    request.log.info({
      responseTime: reply.elapsedTime,
      statusCode: reply.statusCode,
      cache: reply.getHeader('X-Cache') || 'NONE',
      route: request.routeOptions?.url || request.url
    }, 'request completed')
    done()
  });

  // Keep error logs tied to the request context instead of relying on the
  // default Fastify 500 handler alone.
  fastify.addHook('onError', (request, reply, error, done) => {
    request.log.error({
      err: error,
      route: request.routeOptions?.url || request.url,
      statusCode: reply.statusCode
    }, 'request failed')
    done()
  });

  // 2. Graceful Shutdown (Zero-Downtime Rollout connection draining)
  const db = require('./controllers/db');
  fastify.addHook('onClose', async (instance) => {
    // When K8s sends SIGTERM, this ensures active users finish downloading their bills 
    // and then cleanly destroys the active Knex Postgres connection pools.
    await db.knex.destroy();
  });

  fastify.register(AutoLoad, {
    dir: path.join(__dirname, "plugins"),
    options: Object.assign({}, opts),
  });

  // This loads all plugins defined in routes
  // define your routes in one of these
  fastify.register(AutoLoad, {
    dir: path.join(__dirname, "routes"),
    options: Object.assign({}, opts),
  });
};
