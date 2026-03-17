"use strict";

const db = require("../controllers/db");

module.exports = async function (fastify, opts) {
  fastify.get("/bills/bynumber/:number", async (request, reply) => {
    const { number } = request.params;

    if (!/^\d+$/.test(number)) {
      reply.code(400);
      return { error: "Invalid bill number; must be an integer" };
    }

    return db.knex("bills as b")
      .select(
        "b.billid", "b.billtype", "b.congress", "b.billnumber",
        "b.shorttitle", "b.officialtitle", "b.introducedat",
        "b.latest_action_date", "b.sponsor_name", "b.sponsor_party",
        "b.sponsor_state", "b.policy_area", "b.statusat"
      )
      .where("b.billnumber", number)
      .orderByRaw("b.latest_action_date DESC NULLS LAST")
      .orderBy("b.congress", "desc");
  });
};
