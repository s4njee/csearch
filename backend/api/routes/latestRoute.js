const db = require("../controllers/db");
const { VALID_BILL_TYPES } = require("../utils/constants");
const cache = require("../utils/cache");

module.exports = async function (fastify, opts) {
  fastify.get("/latest/:billtype", async (request, reply) => {
    const { billtype } = request.params;

    if (billtype !== "all" && !VALID_BILL_TYPES.has(billtype)) {
      reply.code(400);
      return { error: "Invalid bill type" };
    }

    const cacheKey = `latest_bills_${billtype}`;
    if (cache.has(cacheKey)) {
      reply.header("X-Cache", "HIT");
      return cache.get(cacheKey);
    }

    const committeeCodes = db.knex.raw(
      "(SELECT COALESCE(array_agg(DISTINCT bc.committee_code ORDER BY bc.committee_code), '{}') FROM bill_committees bc WHERE bc.billtype = b.billtype AND bc.billnumber = b.billnumber AND bc.congress = b.congress) AS committee_codes"
    );

    const data = await db.knex
      .select(
        "b.billid", "b.shorttitle", "b.officialtitle", "b.introducedat",
        "b.summary_text", "b.billtype",
        db.knex.raw("b.congress::text AS congress"),
        db.knex.raw("b.billnumber::text AS billnumber"),
        "b.sponsor_name", "b.sponsor_party", "b.sponsor_state", "b.sponsor_bioguide_id",
        "b.bill_status", "b.statusat", "b.policy_area", "b.latest_action_date", "b.origin_chamber",
        committeeCodes,
        db.knex.raw(
          "(SELECT COUNT(*)::int FROM bill_cosponsors bc WHERE bc.billtype = b.billtype AND bc.billnumber = b.billnumber AND bc.congress = b.congress) AS cosponsor_count"
        )
      )
      .from("public.bills as b")
      .where("b.billtype", billtype)
      .orderByRaw("b.latest_action_date DESC NULLS LAST")
      .orderBy("b.billid", "desc")
      .limit(500);

    cache.set(cacheKey, data);
    reply.header("X-Cache", "MISS");
    return data;
  });
};
