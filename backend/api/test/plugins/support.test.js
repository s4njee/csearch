'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const Fastify = require('fastify');
const Support = require('../../plugins/support');

describe('support plugin', () => {
  it('decorates fastify with someSupport() returning "hugs"', async (t) => {
    const fastify = Fastify();
    fastify.register(Support);

    t.after(() => fastify.close());
    await fastify.ready();

    assert.equal(fastify.someSupport(), 'hugs');
  });
});
