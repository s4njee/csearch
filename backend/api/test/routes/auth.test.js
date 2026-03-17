'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { createSigner } = require('fast-jwt');
const { build } = require('../helper');
const db = require('../../controllers/db');
const { createMockKnex } = require('../helpers/mockKnex');
const { SAMPLE_USER } = require('../helpers/fixtures');

// The auth plugin uses this secret (see plugins/auth.js)
const JWT_SECRET = 'supersecret';
const signJwt = createSigner({ key: JWT_SECRET });

function createToken(payload) {
  return signJwt(payload);
}

describe('POST /login', () => {
  const originalKnex = db.knex;

  afterEach(() => {
    db.knex = originalKnex;
  });

  it('creates a new user and returns a JWT token', async (t) => {
    let insertedData = null;

    db.knex = createMockKnex({
      raw: (sql, bindings) => {
        if (sql.includes('exists')) {
          return { rows: [{ exists: false }] };
        }
        return { rows: [] };
      },
    });
    // Wrap knex function to capture insert calls
    const baseMock = db.knex;
    const wrappedKnex = (table) => {
      const chain = baseMock(table);
      chain.insert = async (data) => { insertedData = data; };
      return chain;
    };
    wrappedKnex.select = baseMock.select;
    wrappedKnex.raw = baseMock.raw;
    db.knex = wrappedKnex;

    const app = await build(t);

    const res = await app.inject({
      method: 'POST',
      url: '/login',
      payload: SAMPLE_USER,
    });

    assert.equal(res.statusCode, 200);

    // The route returns JSON.stringify({...}), Fastify sends the string as-is
    const body = JSON.parse(res.payload);
    assert.equal(body.user, SAMPLE_USER.email);
    assert.ok(body.token, 'response should include a JWT token');
    assert.ok(body.token.split('.').length === 3, 'token should be a valid JWT format');

    // Should have inserted the new user
    assert.ok(insertedData, 'should have called insert');
    assert.equal(insertedData.email, SAMPLE_USER.email);
    assert.equal(insertedData.firstname, SAMPLE_USER.given_name);
    assert.equal(insertedData.lastname, SAMPLE_USER.family_name);
  });

  it('returns a JWT for an existing user without inserting', async (t) => {
    let insertCalled = false;

    db.knex = createMockKnex({
      raw: (sql) => {
        if (sql.includes('exists')) {
          return { rows: [{ exists: true }] };
        }
        return { rows: [] };
      },
    });
    const baseMock = db.knex;
    const wrappedKnex = (table) => {
      const chain = baseMock(table);
      chain.insert = async () => { insertCalled = true; };
      return chain;
    };
    wrappedKnex.select = baseMock.select;
    wrappedKnex.raw = baseMock.raw;
    db.knex = wrappedKnex;

    const app = await build(t);

    const res = await app.inject({
      method: 'POST',
      url: '/login',
      payload: SAMPLE_USER,
    });

    assert.equal(res.statusCode, 200);
    assert.equal(insertCalled, false, 'should not insert existing user');

    const body = JSON.parse(res.payload);
    assert.ok(body.token, 'should still return a token');
  });
});

describe('POST /addVote', () => {
  const originalKnex = db.knex;

  afterEach(() => {
    db.knex = originalKnex;
  });

  it('returns 401 without authentication', async (t) => {
    db.knex = createMockKnex();
    const app = await build(t);

    const res = await app.inject({
      method: 'POST',
      url: '/addVote',
      payload: { billid: 1, email: 'a@b.com' },
    });

    assert.equal(res.statusCode, 401);
  });

  it('adds a vote with a valid JWT', async (t) => {
    const rawCalls = [];

    db.knex = createMockKnex({
      tables: {
        bills: [{ votes: [] }],
      },
      raw: (sql, bindings) => {
        rawCalls.push({ sql, bindings });
        return { rows: [] };
      },
    });
    const app = await build(t);

    const token = createToken({ email: SAMPLE_USER.email });

    const res = await app.inject({
      method: 'POST',
      url: '/addVote',
      headers: { authorization: `Bearer ${token}` },
      payload: { billid: 1001, email: SAMPLE_USER.email },
    });

    assert.equal(res.statusCode, 200);
    assert.deepStrictEqual(JSON.parse(res.payload), { ok: true });

    // Should have called raw() for UPDATE bills SET votes and votecount
    assert.ok(rawCalls.length >= 2, 'should have executed UPDATE queries');
    assert.ok(
      rawCalls.some((c) => c.sql.includes('SET votes')),
      'should update the votes JSONB column',
    );
    assert.ok(
      rawCalls.some((c) => c.sql.includes('votecount')),
      'should increment votecount',
    );
  });

  it('does not duplicate an existing vote', async (t) => {
    const rawCalls = [];

    db.knex = createMockKnex({
      tables: {
        // User email already in the votes array
        bills: [{ votes: [SAMPLE_USER.email] }],
      },
      raw: (sql, bindings) => {
        rawCalls.push({ sql, bindings });
        return { rows: [] };
      },
    });
    const app = await build(t);
    const token = createToken({ email: SAMPLE_USER.email });

    await app.inject({
      method: 'POST',
      url: '/addVote',
      headers: { authorization: `Bearer ${token}` },
      payload: { billid: 1001, email: SAMPLE_USER.email },
    });

    assert.equal(rawCalls.length, 0, 'should not run UPDATE when email already voted');
  });
});

describe('POST /removeVote', () => {
  const originalKnex = db.knex;

  afterEach(() => {
    db.knex = originalKnex;
  });

  it('returns 401 without authentication', async (t) => {
    db.knex = createMockKnex();
    const app = await build(t);

    const res = await app.inject({
      method: 'POST',
      url: '/removeVote',
      payload: { billid: 1, email: 'a@b.com' },
    });

    assert.equal(res.statusCode, 401);
  });

  it('removes a vote with a valid JWT', async (t) => {
    const rawCalls = [];

    db.knex = createMockKnex({
      tables: {
        bills: [{ votes: [SAMPLE_USER.email] }],
      },
      raw: (sql, bindings) => {
        rawCalls.push({ sql, bindings });
        return { rows: [] };
      },
    });
    const app = await build(t);
    const token = createToken({ email: SAMPLE_USER.email });

    const res = await app.inject({
      method: 'POST',
      url: '/removeVote',
      headers: { authorization: `Bearer ${token}` },
      payload: { billid: 1001, email: SAMPLE_USER.email },
    });

    assert.equal(res.statusCode, 200);
    assert.deepStrictEqual(JSON.parse(res.payload), { ok: true });

    assert.ok(rawCalls.length >= 2, 'should have executed UPDATE queries');
    assert.ok(
      rawCalls.some((c) => c.sql.includes('votes - ')),
      'should remove email from votes JSONB',
    );
    assert.ok(
      rawCalls.some((c) => c.sql.includes('GREATEST')),
      'should decrement votecount with floor of 0',
    );
  });

  it('is a no-op when user has not voted', async (t) => {
    const rawCalls = [];

    db.knex = createMockKnex({
      tables: {
        bills: [{ votes: [] }],
      },
      raw: (sql, bindings) => {
        rawCalls.push({ sql, bindings });
        return { rows: [] };
      },
    });
    const app = await build(t);
    const token = createToken({ email: SAMPLE_USER.email });

    await app.inject({
      method: 'POST',
      url: '/removeVote',
      headers: { authorization: `Bearer ${token}` },
      payload: { billid: 1001, email: SAMPLE_USER.email },
    });

    assert.equal(rawCalls.length, 0, 'should not run UPDATE when user has no vote');
  });
});
