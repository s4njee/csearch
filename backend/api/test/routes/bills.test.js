'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { build } = require('../helper');
const db = require('../../controllers/db');
const { createMockKnex } = require('../helpers/mockKnex');
const {
  SAMPLE_BILL_DETAIL,
  SAMPLE_ACTION,
  SAMPLE_COSPONSOR,
  SAMPLE_BILL_VOTE,
} = require('../helpers/fixtures');

describe('GET /bills/:billtype/:congress/:billnumber', () => {
  const originalKnex = db.knex;

  afterEach(() => {
    db.knex = originalKnex;
  });

  it('returns 200 with full bill detail including actions, cosponsors, votes', async (t) => {
    db.knex = createMockKnex({
      tables: {
        bills: [SAMPLE_BILL_DETAIL],
        bill_actions: [SAMPLE_ACTION],
        bill_cosponsors: [SAMPLE_COSPONSOR],
        votes: [SAMPLE_BILL_VOTE],
      },
    });
    const app = await build(t);

    const res = await app.inject({
      method: 'GET',
      url: '/bills/hr/119/42',
    });

    assert.equal(res.statusCode, 200);

    const body = JSON.parse(res.payload);
    assert.equal(body.billid, SAMPLE_BILL_DETAIL.billid);
    assert.equal(body.billtype, 'hr');
    assert.ok(Array.isArray(body.actions), 'should have actions array');
    assert.ok(Array.isArray(body.cosponsors), 'should have cosponsors array');
    assert.ok(Array.isArray(body.votes), 'should have votes array');
    assert.equal(body.actions.length, 1);
    assert.equal(body.cosponsors.length, 1);
    assert.equal(body.votes.length, 1);
  });

  it('includes all expected top-level fields', async (t) => {
    db.knex = createMockKnex({
      tables: {
        bills: [SAMPLE_BILL_DETAIL],
        bill_actions: [],
        bill_cosponsors: [],
        votes: [],
      },
    });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/bills/hr/119/42' });
    const body = JSON.parse(res.payload);

    const expectedKeys = [
      'billid', 'billnumber', 'billtype', 'congress',
      'shorttitle', 'officialtitle', 'introducedat', 'statusat',
      'bill_status',
      'summary_text', 'summary_date',
      'sponsor_name', 'sponsor_party', 'sponsor_state', 'sponsor_bioguide_id',
      'origin_chamber', 'policy_area', 'update_date', 'latest_action_date',
      'actions', 'cosponsors', 'votes',
    ];

    for (const key of expectedKeys) {
      assert.ok(key in body, `response should contain "${key}"`);
    }
  });

  it('returns 404 when the bill is not found', async (t) => {
    db.knex = createMockKnex({
      tables: {
        bills: [],           // no bill => .first() returns null
        bill_actions: [],
        bill_cosponsors: [],
        votes: [],
      },
    });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/bills/hr/119/9999' });

    assert.equal(res.statusCode, 404);
    assert.equal(JSON.parse(res.payload).error, 'Bill not found');
  });

  it('returns empty sub-arrays when bill has no actions/cosponsors/votes', async (t) => {
    db.knex = createMockKnex({
      tables: {
        bills: [SAMPLE_BILL_DETAIL],
        bill_actions: [],
        bill_cosponsors: [],
        votes: [],
      },
    });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/bills/hr/119/42' });
    const body = JSON.parse(res.payload);

    assert.deepStrictEqual(body.actions, []);
    assert.deepStrictEqual(body.cosponsors, []);
    assert.deepStrictEqual(body.votes, []);
  });

  // --- Validation errors ---

  it('returns 400 for an invalid bill type', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/bills/invalid/119/1' });

    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.payload).error, 'Invalid bill type');
  });

  it('returns 400 for a non-numeric congress', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/bills/hr/abc/1' });

    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.payload).error, 'Invalid congress; must be a number');
  });

  it('returns 400 for a non-numeric bill number', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/bills/hr/119/abc' });

    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.payload).error, 'Invalid bill number; must be a number');
  });
});
