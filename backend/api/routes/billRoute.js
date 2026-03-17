const db = require("../controllers/db");
const { VALID_BILL_TYPES } = require("../utils/constants");

module.exports = async function (fastify, opts) {
  fastify.get("/bills/:billtype/:congress/:billnumber", async (request, reply) => {
    const { billtype, congress, billnumber } = request.params;

    if (!VALID_BILL_TYPES.has(billtype)) {
      reply.code(400);
      return { error: "Invalid bill type" };
    }

    if (!/^\d+$/.test(congress)) {
      reply.code(400);
      return { error: "Invalid congress; must be a number" };
    }

    if (!/^\d+$/.test(billnumber)) {
      reply.code(400);
      return { error: "Invalid bill number; must be a number" };
    }

    const [bill, actions, cosponsors, votes] = await Promise.all([
      db.knex("bills")
        .where({ billtype, congress, billnumber })
        .select(
          "billid", "billnumber", "billtype", "congress",
          "shorttitle", "officialtitle", "introducedat", "statusat",
          "summary_text", "summary_date",
          "sponsor_name", "sponsor_party", "sponsor_state", "sponsor_bioguide_id",
          "origin_chamber", "policy_area", "update_date", "latest_action_date"
        )
        .first(),

      db.knex("bill_actions")
        .where({ billtype, congress, billnumber })
        .select("acted_at", "action_text", "action_type", "action_code")
        .orderBy("acted_at", "asc"),

      db.knex("bill_cosponsors")
        .where({ billtype, congress, billnumber })
        .select("bioguide_id", "full_name", "state", "party", "sponsorship_date", "is_original_cosponsor")
        .orderBy("sponsorship_date", "asc"),

      db.knex("votes")
        .where({ bill_type: billtype, bill_number: billnumber, congress })
        .select("voteid", "congress", "chamber", "question", "result", "votedate", "votetype")
        .orderBy("votedate", "desc"),
    ]);

    if (!bill) {
      reply.code(404);
      return { error: "Bill not found" };
    }

    return { ...bill, actions, cosponsors, votes };
  });
};
