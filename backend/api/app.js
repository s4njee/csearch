"use strict";

const path = require("path");
const AutoLoad = require("@fastify/autoload");
const cors = require("@fastify/cors");

// Fastify options: trustProxy ensures we get real user IPs behind CloudFront/K8s
// instead of blocking EVERYONE as 1 IP through the rate limiter!
const appOptions = {
  trustProxy: true,
  logger: {
    level: process.env.LOG_LEVEL || "info",
    serializers: {
      req(req) {
        return { method: req.method, url: req.url, ip: req.ip, reqId: req.id };
      },
      res(res) {
        return { statusCode: res.statusCode };
      }
    },
    // Keep the admin secret out of stdout logs.
    redact: ["req.headers.authorization"]
  }
};

async function app(fastify, opts) {
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
  fastify.setErrorHandler((error, request, reply) => {
    const statusCode = error.statusCode || 500;
    const log = statusCode >= 500 ? request.log.error.bind(request.log) : request.log.warn.bind(request.log);

    log({
      err: error,
      route: request.routeOptions?.url || request.url,
      statusCode
    }, 'request failed');

    if (error.headers) {
      reply.headers(error.headers);
    }

    reply.status(statusCode).send(error);
  });

  // 2. Graceful Shutdown (Zero-Downtime Rollout connection draining)
  const db = require('./controllers/db');
  const cache = require('./utils/cache');
  fastify.addHook('onClose', async (instance) => {
    // When K8s sends SIGTERM, this ensures active users finish downloading their bills 
    // and then cleanly destroys the active Knex Postgres and Redis connections.
    await cache.quit();
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
}

app.options = appOptions;

module.exports = app;
