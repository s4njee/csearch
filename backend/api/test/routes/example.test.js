'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { build } = require('../helper');

describe('GET /example', () => {
  it('returns 200 with "this is an example"', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/example' });

    assert.equal(res.statusCode, 200);
    assert.equal(res.payload, 'this is an example');
  });
});
