'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { build } = require('../helper');
const db = require('../../controllers/db');
const { createMockKnex } = require('../helpers/mockKnex');
const { SAMPLE_BILL_LIST_ITEM } = require('../helpers/fixtures');
const { VALID_BILL_TYPES } = require('../../utils/constants');

describe('GET /latest/:billtype', () => {
  const originalKnex = db.knex;

  afterEach(() => {
    db.knex = originalKnex;
  });

  it('returns 200 with an array of bills for a valid type', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [SAMPLE_BILL_LIST_ITEM] } });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/latest/hr' });

    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.payload);
    assert.ok(Array.isArray(body), 'response should be an array');
    assert.equal(body.length, 1);
  });

  it('returns the expected bill shape', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [SAMPLE_BILL_LIST_ITEM] } });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/latest/hr' });
    const [bill] = JSON.parse(res.payload);

    const expectedKeys = [
      'billid', 'shorttitle', 'officialtitle', 'introducedat',
      'summary_text', 'billtype', 'congress', 'billnumber',
      'sponsor_name', 'sponsor_party', 'sponsor_state', 'sponsor_bioguide_id',
      'statusat', 'policy_area', 'latest_action_date', 'origin_chamber',
      'cosponsor_count',
    ];

    for (const key of expectedKeys) {
      assert.ok(key in bill, `bill should have key "${key}"`);
    }
  });

  it('returns 400 for an invalid bill type', async (t) => {
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/latest/invalid' });

    assert.equal(res.statusCode, 400);
    const body = JSON.parse(res.payload);
    assert.equal(body.error, 'Invalid bill type');
  });

  for (const billtype of VALID_BILL_TYPES) {
    it(`accepts "${billtype}" as a valid bill type`, async (t) => {
      db.knex = createMockKnex({ tables: { bills: [] } });
      const app = await build(t);

      const res = await app.inject({ method: 'GET', url: `/latest/${billtype}` });

      assert.equal(res.statusCode, 200);
    });
  }

  it('returns an empty array when no bills match', async (t) => {
    db.knex = createMockKnex({ tables: { bills: [] } });
    const app = await build(t);

    const res = await app.inject({ method: 'GET', url: '/latest/s' });

    assert.equal(res.statusCode, 200);
    assert.deepStrictEqual(JSON.parse(res.payload), []);
  });
});
