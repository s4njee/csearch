'use strict';

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const {
  getExploreQueries,
  getExploreQuery,
  executeExploreQuery,
} = require('../../services/exploreQueries');

// ---------------------------------------------------------------------------
// getExploreQueries
// ---------------------------------------------------------------------------

describe('getExploreQueries()', () => {
  it('returns exactly 17 queries', () => {
    const queries = getExploreQueries();
    assert.equal(queries.length, 17);
  });

  it('each query has the expected shape', () => {
    const queries = getExploreQueries();

    for (const q of queries) {
      assert.ok(typeof q.id === 'string' && q.id.length > 0, `id should be a non-empty string: ${q.id}`);
      assert.ok(typeof q.number === 'number', `number should be a number: ${q.number}`);
      assert.ok(typeof q.title === 'string' && q.title.length > 0, `title should be a non-empty string`);
      assert.ok(q.path.startsWith('/explore/'), `path should start with /explore/: ${q.path}`);
      assert.ok(Array.isArray(q.parameters), 'parameters should be an array');
    }
  });

  it('queries are numbered sequentially 1..17', () => {
    const queries = getExploreQueries();
    const numbers = queries.map((q) => q.number);

    for (let i = 1; i <= 17; i++) {
      assert.ok(numbers.includes(i), `should include query number ${i}`);
    }
  });

  it('query IDs match well-known identifiers', () => {
    const queries = getExploreQueries();
    const ids = queries.map((q) => q.id);

    const expectedIds = [
      'recent-bills',
      'largest-cosponsor-coalitions',
      'top-subject-areas',
      'active-committees',
      'deepest-action-history',
      'missing-descriptive-fields',
      'largest-vote-margins',
      'closest-votes',
      'most-not-voting-members',
      'broad-sponsorship-history',
      'bill-search-example',
      'vote-search-example',
      'most-prolific-sponsors',
      'bipartisan-bills',
      'policy-area-by-congress',
      'bills-with-floor-votes',
      'party-line-crossovers',
    ];

    for (const id of expectedIds) {
      assert.ok(ids.includes(id), `query list should include "${id}"`);
    }
  });

  it('parameterized queries expose their parameter definitions', () => {
    const queries = getExploreQueries();
    const billSearch = queries.find((q) => q.id === 'bill-search-example');

    assert.ok(billSearch);
    assert.equal(billSearch.parameters.length, 4);

    const [q, billType, congress, limit] = billSearch.parameters;
    assert.equal(q.name, 'q');
    assert.equal(q.type, 'string');
    assert.equal(billType.name, 'billType');
    assert.equal(congress.name, 'congress');
    assert.equal(limit.name, 'limit');
    assert.equal(limit.type, 'integer');
    assert.equal(limit.min, 1);
    assert.equal(limit.max, 100);
    assert.equal(limit.default, 20);
  });

  it('non-parameterized queries have empty parameters array', () => {
    const queries = getExploreQueries();
    const recentBills = queries.find((q) => q.id === 'recent-bills');

    assert.ok(recentBills);
    assert.deepStrictEqual(recentBills.parameters, []);
  });
});

// ---------------------------------------------------------------------------
// getExploreQuery
// ---------------------------------------------------------------------------

describe('getExploreQuery()', () => {
  it('returns a query by ID', () => {
    const q = getExploreQuery('recent-bills');

    assert.ok(q);
    assert.equal(q.id, 'recent-bills');
    assert.equal(q.number, 1);
    assert.ok(q.sql.length > 0, 'sql should not be empty');
  });

  it('returns null for an unknown ID', () => {
    assert.equal(getExploreQuery('does-not-exist'), null);
  });
});

// ---------------------------------------------------------------------------
// executeExploreQuery
// ---------------------------------------------------------------------------

describe('executeExploreQuery()', () => {
  it('returns null for an unknown query', async () => {
    const mockKnex = { raw: async () => ({ rows: [] }) };
    const result = await executeExploreQuery(mockKnex, 'nonexistent', {});
    assert.equal(result, null);
  });

  it('executes a non-parameterized query via knex.raw', async () => {
    let capturedSql;
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedSql = sql;
        capturedBindings = bindings;
        return { rows: [{ count: 5 }] };
      },
    };

    const result = await executeExploreQuery(mockKnex, 'recent-bills', {});

    assert.ok(result);
    assert.equal(result.query.id, 'recent-bills');
    assert.ok(capturedSql.length > 0);
    assert.deepStrictEqual(capturedBindings, []);
    assert.deepStrictEqual(result.rows, [{ count: 5 }]);
  });

  it('builds correct SQL and bindings for bill-search-example', async () => {
    let capturedSql;
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedSql = sql;
        capturedBindings = bindings;
        return { rows: [] };
      },
    };

    await executeExploreQuery(mockKnex, 'bill-search-example', {
      q: 'climate',
      billType: 'hr',
      congress: '118',
      limit: '50',
    });

    assert.equal(capturedSql, 'SELECT * FROM search_bills(?, ?, ?, ?);');
    assert.deepStrictEqual(capturedBindings, ['climate', 'hr', '118', 50]);
  });

  it('builds correct SQL and bindings for vote-search-example', async () => {
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedBindings = bindings;
        return { rows: [] };
      },
    };

    await executeExploreQuery(mockKnex, 'vote-search-example', {
      q: 'cloture',
      congress: '119',
      chamber: 'senate',
      limit: '10',
    });

    assert.deepStrictEqual(capturedBindings, ['cloture', '119', 'senate', 10]);
  });

  it('uses default values when parameters are omitted', async () => {
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedBindings = bindings;
        return { rows: [] };
      },
    };

    await executeExploreQuery(mockKnex, 'bill-search-example', {});

    assert.equal(capturedBindings[0], 'clean energy tax credit');
    assert.equal(capturedBindings[1], null);  // billType
    assert.equal(capturedBindings[2], null);  // congress
    assert.equal(capturedBindings[3], 20);    // default limit
  });

  it('clamps limit to 1 when value is below minimum', async () => {
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedBindings = bindings;
        return { rows: [] };
      },
    };

    await executeExploreQuery(mockKnex, 'bill-search-example', { limit: '0' });

    assert.equal(capturedBindings[3], 1);
  });

  it('clamps limit to 100 when value exceeds maximum', async () => {
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedBindings = bindings;
        return { rows: [] };
      },
    };

    await executeExploreQuery(mockKnex, 'bill-search-example', { limit: '999' });

    assert.equal(capturedBindings[3], 100);
  });

  it('falls back to default limit for non-numeric input', async () => {
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedBindings = bindings;
        return { rows: [] };
      },
    };

    await executeExploreQuery(mockKnex, 'bill-search-example', { limit: 'abc' });

    assert.equal(capturedBindings[3], 20);
  });

  it('normalizes empty string parameters to null', async () => {
    let capturedBindings;

    const mockKnex = {
      raw: async (sql, bindings) => {
        capturedBindings = bindings;
        return { rows: [] };
      },
    };

    await executeExploreQuery(mockKnex, 'bill-search-example', {
      q: 'test',
      billType: '',
      congress: '',
    });

    assert.equal(capturedBindings[1], null);
    assert.equal(capturedBindings[2], null);
  });

  it('returns sql and bindings in the result envelope', async () => {
    const mockKnex = {
      raw: async () => ({ rows: [] }),
    };

    const result = await executeExploreQuery(mockKnex, 'bill-search-example', { q: 'test' });

    assert.ok(result);
    assert.equal(typeof result.sql, 'string');
    assert.ok(Array.isArray(result.bindings));
    assert.ok(Array.isArray(result.rows));
    assert.ok(result.query);
    assert.equal(result.query.id, 'bill-search-example');
  });
});
