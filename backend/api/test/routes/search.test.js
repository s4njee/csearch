'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { build } = require('../helper');
const db = require('../../controllers/db');
const { createMockKnex } = require('../helpers/mockKnex');
const { SAMPLE_BILL_LIST_ITEM } = require('../helpers/fixtures');

describe('GET /search/:table/:filter', () => {
  const originalKnex = db.knex;

  afterEach(() => {
    db.knex = originalKnex;
  });

  // --- Happy paths ---

  it('returns 200 with relevance-sorted results', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [SAMPLE_BILL_LIST_ITEM] } });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/hr/relevance?query=infrastructure',
    });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.ok(Array.isArray(body));
    assert.equal(body.length, 1);
  });

  it('returns 200 for the all-bills search route', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [SAMPLE_BILL_LIST_ITEM] } });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/all/relevance?query=infrastructure',
    });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.ok(Array.isArray(body));
    assert.equal(body.length, 1);
  });

  it('returns 200 with date-sorted results', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [SAMPLE_BILL_LIST_ITEM] } });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/hr/date?query=infrastructure',
    });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.ok(Array.isArray(body));
  });

  it('returns an empty array when nothing matches', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [] } });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/s/relevance?query=xyznonexistent',
    });

    assert.equal(res.statusCode, 200);
    assert.deepStrictEqual(JSON.parse(res.payload), []);
  });

  // --- Validation errors ---

  it('returns 400 for an invalid bill type', async (t) => {
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/invalid/relevance?query=test',
    });

    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.payload).error, 'Invalid bill type');
  });

  it('returns 400 when the query parameter is missing', async (t) => {
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/hr/relevance',
    });

    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.payload).error, 'Missing required query parameter');
  });

  it('returns 400 for an empty query string', async (t) => {
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/hr/relevance?query=',
    });

    assert.equal(res.statusCode, 400);
  });

  it('returns 400 for a whitespace-only query', async (t) => {
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/hr/relevance?query=%20%20',
    });

    assert.equal(res.statusCode, 400);
  });

  it('returns 400 for an invalid filter value', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [] } });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/search/hr/popularity?query=test',
    });

    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.payload).error, "Invalid filter; use 'relevance' or 'date'");
  });
});
