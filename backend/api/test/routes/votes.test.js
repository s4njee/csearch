'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { build } = require('../helper');
const db = require('../../controllers/db');
const { createMockKnex } = require('../helpers/mockKnex');
const { SAMPLE_VOTE_WITH_COUNTS } = require('../helpers/fixtures');

describe('GET /votes/:chamber', () => {
  const originalKnex = db.knex;

  afterEach(() => {
    db.knex = originalKnex;
  });

  it('returns 200 with house votes', async (t) => {
    db.knex = createMockKnex({ tables: { votes: [SAMPLE_VOTE_WITH_COUNTS] } });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/votes/house' });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.ok(Array.isArray(body));
    assert.equal(body.length, 1);
  });

  it('returns 200 with senate votes', async (t) => {
    const senateVote = { ...SAMPLE_VOTE_WITH_COUNTS, chamber: 'senate', voteid: 's1-119.2025' };
    db.knex = createMockKnex({ tables: { votes: [senateVote] } });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/votes/senate' });

    assert.equal(res.statusCode, 200);
    assert.ok(Array.isArray(JSON.parse(res.payload)));
  });

  it('returns the expected vote shape with tally counts', async (t) => {
    db.knex = createMockKnex({ tables: { votes: [SAMPLE_VOTE_WITH_COUNTS] } });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/votes/house' });
    const [vote] = JSON.parse(res.payload);

    const expectedKeys = [
      'congress', 'votenumber', 'votedate', 'question',
      'votesession', 'result', 'chamber', 'votetype',
      'voteid', 'source_url',
      'yea', 'nay', 'present', 'notvoting',
    ];

    for (const key of expectedKeys) {
      assert.ok(key in vote, `vote should have key "${key}"`);
    }

    // Tally counts should be numbers
    assert.equal(typeof vote.yea, 'number');
    assert.equal(typeof vote.nay, 'number');
    assert.equal(typeof vote.present, 'number');
    assert.equal(typeof vote.notvoting, 'number');
  });

  it('returns 400 for an invalid chamber', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/votes/invalid' });

    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.payload).error, "Invalid chamber; use 'house' or 'senate'");
  });

  it('returns an empty array when no votes match', async (t) => {
    db.knex = createMockKnex({ tables: { votes: [] } });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/votes/house' });

    assert.equal(res.statusCode, 200);
    assert.deepStrictEqual(JSON.parse(res.payload), []);
  });
});
