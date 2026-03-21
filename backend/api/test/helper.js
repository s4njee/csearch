'use strict';

const { build: buildApplication } = require('fastify-cli/helper');
const path = require('node:path');
const cache = require('../utils/cache');

const APP_PATH = path.join(__dirname, '..', 'app.js');

// Ensure env vars needed by plugins (OAuth2, etc.) are available during tests
process.env.GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || 'test-client-id';
process.env.GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || 'test-client-secret';

/**
 * Build a Fastify app instance for testing.
 * Registers automatic teardown via t.after (node:test) or t.teardown (tap).
 */
async function build(t) {
  await cache.reset();
  const app = await buildApplication([APP_PATH], {});

  const cleanup = t.after || t.teardown;
  if (cleanup) {
    cleanup.call(t, () => app.close());
  }

  return app;
}

module.exports = { build };
