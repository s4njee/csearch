const db = require("../controllers/db");
const { VALID_BILL_TYPES } = require("../utils/constants");

module.exports = async function (fastify, opts) {
  fastify.get("/latest/:billtype", async (request, reply) => {
    const { billtype } = request.params;

    if (!VALID_BILL_TYPES.has(billtype)) {
      reply.code(400);
      return { error: "Invalid bill type" };
    }

    return db.knex
      .select(
        "b.billid", "b.shorttitle", "b.officialtitle", "b.introducedat",
        "b.summary_text", "b.billtype", "b.congress", "b.billnumber",
        "b.sponsor_name", "b.sponsor_party", "b.sponsor_state", "b.sponsor_bioguide_id",
        "b.statusat", "b.policy_area", "b.latest_action_date", "b.origin_chamber",
        db.knex.raw(
          "(SELECT COUNT(*)::int FROM bill_cosponsors bc WHERE bc.billtype = b.billtype AND bc.billnumber = b.billnumber AND bc.congress = b.congress) AS cosponsor_count"
        )
      )
      .from("public.bills as b")
      .where("b.billtype", billtype)
      .orderByRaw("b.latest_action_date DESC NULLS LAST")
      .orderBy("b.billid", "desc")
      .limit(500);
  });
};
