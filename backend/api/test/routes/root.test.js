'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { build } = require('../helper');

describe('GET /', () => {
  it('returns 200 with { root: true }', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/' });

    assert.equal(res.statusCode, 200);
    assert.deepStrictEqual(JSON.parse(res.payload), { root: true });
  });

  it('sets content-type to application/json', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/' });

    assert.match(res.headers['content-type'], /application\/json/);
  });
});
