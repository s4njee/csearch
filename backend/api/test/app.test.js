'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const app = require('../app');

describe('app startup options', () => {
  it('exports Fastify CLI options for trustProxy and structured logging', () => {
    assert.equal(app.options.trustProxy, true);
    assert.equal(app.options.logger.level, process.env.LOG_LEVEL || 'info');
    assert.deepStrictEqual(app.options.logger.redact, ['req.headers.authorization']);
    assert.equal(typeof app.options.logger.serializers.req, 'function');
    assert.equal(typeof app.options.logger.serializers.res, 'function');
  });
});
