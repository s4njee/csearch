'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { build } = require('../helper');
const db = require('../../controllers/db');
const { createMockKnex } = require('../helpers/mockKnex');

describe('GET /explore', () => {
  const originalKnex = db.knex;
  afterEach(() => { db.knex = originalKnex; });

  it('returns 200 with a list of 17 explore queries', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/explore' });

    assert.equal(res.statusCode, 200);
    const { queries } = JSON.parse(res.payload);
    assert.equal(queries.length, 17);
  });

  it('includes correct metadata for each query', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/explore' });
    const { queries } = JSON.parse(res.payload);

    for (const q of queries) {
      assert.ok(q.id, 'query should have an id');
      assert.ok(typeof q.number === 'number', 'query.number should be a number');
      assert.ok(q.title, 'query should have a title');
      assert.ok(q.path.startsWith('/explore/'), 'path should start with /explore/');
      assert.ok(Array.isArray(q.parameters), 'parameters should be an array');
    }
  });

  it('includes parameter definitions for bill-search-example', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/explore' });
    const { queries } = JSON.parse(res.payload);
    const billSearch = queries.find((q) => q.id === 'bill-search-example');

    assert.ok(billSearch, 'should contain bill-search-example');
    assert.equal(billSearch.parameters.length, 4);
    assert.equal(billSearch.parameters[0].name, 'q');
    assert.equal(billSearch.parameters[3].name, 'limit');
    assert.equal(billSearch.parameters[3].max, 100);
  });

  it('includes parameter definitions for vote-search-example', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/explore' });
    const { queries } = JSON.parse(res.payload);
    const voteSearch = queries.find((q) => q.id === 'vote-search-example');

    assert.ok(voteSearch, 'should contain vote-search-example');
    assert.equal(voteSearch.parameters.length, 4);
    assert.equal(voteSearch.parameters[0].name, 'q');
  });
});

describe('GET /explore/:queryId', () => {
  const originalKnex = db.knex;
  afterEach(() => { db.knex = originalKnex; });

  it('runs the parameterized bill search query', async (t) => {
    db.knex = createMockKnex({
      raw: (sql, bindings) => {
        assert.equal(sql, 'SELECT * FROM search_bills(?, ?, ?, ?);');
        assert.deepStrictEqual(bindings, ['solar tax', 'hr', '118', 5]);
        return { rows: [{ billtype: 'hr', billnumber: '1' }] };
      },
    });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/explore/bill-search-example?q=solar%20tax&billType=hr&congress=118&limit=5',
    });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.equal(body.query.id, 'bill-search-example');
    assert.equal(body.results.length, 1);
    assert.equal(body.sql, 'SELECT * FROM search_bills(?, ?, ?, ?);');
    assert.deepStrictEqual(body.bindings, ['solar tax', 'hr', '118', 5]);
  });

  it('runs the parameterized vote search query', async (t) => {
    db.knex = createMockKnex({
      raw: (sql, bindings) => {
        assert.equal(sql, 'SELECT * FROM search_votes(?, ?, ?, ?);');
        return { rows: [{ voteid: 's1-119' }] };
      },
    });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/explore/vote-search-example?q=cloture&congress=119&chamber=senate&limit=10',
    });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.equal(body.query.id, 'vote-search-example');
    assert.equal(body.results.length, 1);
  });

  it('uses defaults when optional parameters are omitted', async (t) => {
    db.knex = createMockKnex({
      raw: (sql, bindings) => {
        // Should use the default query text and null for optional params
        assert.equal(bindings[0], 'clean energy tax credit');
        assert.equal(bindings[1], null); // billType
        assert.equal(bindings[2], null); // congress
        assert.equal(bindings[3], 20);   // default limit
        return { rows: [] };
      },
    });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/explore/bill-search-example',
    });

    assert.equal(res.statusCode, 200);
  });

  it('runs a non-parameterized query', async (t) => {
    db.knex = createMockKnex({
      raw: (sql, bindings) => {
        assert.deepStrictEqual(bindings, []);
        return { rows: [{ count: 42 }] };
      },
    });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/explore/recent-bills',
    });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.equal(body.query.id, 'recent-bills');
    assert.equal(body.results.length, 1);
  });

  it('returns 404 for an unknown query', async (t) => {
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/explore/not-a-real-query',
    });

    assert.equal(res.statusCode, 404);
    assert.match(JSON.parse(res.payload).error, /Not Found/);
  });
});

describe('explore SQL alignment', () => {
  it('bundled SQL stays in sync with updater SQL', async () => {
    const bundled = fs.readFileSync(
      path.join(__dirname, '..', '..', 'sql', 'explore.sql'),
      'utf8',
    );
    const updater = fs.readFileSync(
      path.join(__dirname, '..', '..', '..', 'updater', 'explore.sql'),
      'utf8',
    );

    assert.equal(bundled, updater, 'congress_api/sql/explore.sql should match updater/explore.sql');
  });
});
