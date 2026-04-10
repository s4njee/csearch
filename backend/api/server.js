'use strict'

// Read the .env file.
require('dotenv').config()

// Require the framework
const Fastify = require('fastify')

// Require library to exit fastify process, gracefully (if possible)
const closeWithGrace = require('close-with-grace')

// Instantiate Fastify with some config
const app = Fastify({
  trustProxy: true,
  // Emit JSON logs to stdout so Kubernetes can collect them without a sidecar.
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    serializers: {
      req(req) {
        return { method: req.method, url: req.url, ip: req.ip, reqId: req.id }
      },
      res(res) {
        return { statusCode: res.statusCode }
      }
    },
    // Keep the admin secret out of stdout logs.
    redact: ['req.headers.authorization']
  }
})

// Register your application as a normal plugin.
const appService = require('./app.js')
app.addHook('onResponse', (request, reply, done) => {
  request.log.info({
    responseTime: reply.elapsedTime,
    statusCode: reply.statusCode,
    cache: reply.getHeader('X-Cache') || 'NONE',
    clientIp: request.ip,
    route: request.routeOptions?.url || request.url
  }, 'request completed')
  done()
})

app.setErrorHandler((error, request, reply) => {
  const statusCode = error.statusCode || 500
  const log = statusCode >= 500 ? request.log.error.bind(request.log) : request.log.warn.bind(request.log)

  log({
    err: error,
    clientIp: request.ip,
    route: request.routeOptions?.url || request.url,
    statusCode
  }, 'request failed')

  if (error.headers) {
    reply.headers(error.headers)
  }

  reply.status(statusCode).send(error)
})

app.register(appService)

// delay is the number of milliseconds for the graceful close to finish
const closeListeners = closeWithGrace({ delay: process.env.FASTIFY_CLOSE_GRACE_DELAY || 500 }, async function ({ signal, err, manual }) {
  if (err) {
    app.log.error(err)
  }
  await app.close()
})

app.addHook('onClose', async (instance, done) => {
  closeListeners.uninstall()
  done()
})

// Bind to all interfaces in containers unless overridden.
app.listen({ host: process.env.HOST || '0.0.0.0', port: process.env.PORT || 3000 }, (err) => {
  if (err) {
    app.log.error(err)
    process.exit(1)
  }
})
