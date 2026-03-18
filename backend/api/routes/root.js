'use strict'
module.exports = async function (fastify, opts) {
  fastify.get('/', async function (request, reply) {
    return { root: true }
  })

  // 3. Deep Health Probes (Enterprise Readiness)
  fastify.get('/health', async function (request, reply) {
    try {
      const db = require('../controllers/db')
      // Actually execute a Knex query to guarantee the connection pool is healthy
      await db.knex.raw('SELECT 1')
      return reply.code(200).send({ status: 'ok', db: 'connected' })
    } catch (err) {
      fastify.log.error({ err }, 'Deep health check failed - DB disconnected')
      return reply.code(503).send({ status: 'error', db: 'disconnected' })
    }
  })
}
