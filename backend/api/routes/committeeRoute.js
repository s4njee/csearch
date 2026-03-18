const db = require("../controllers/db");

module.exports = async function (fastify, opts) {
  fastify.get("/committees", async (request, reply) => {
    const records = await db.knex("bill_committees")
      .select("committee_code", "committee_name", "chamber")
      .count("* as bill_count")
      .groupBy("committee_code", "committee_name", "chamber")
      .orderBy("committee_name", "asc");
      
    return records;
  });

  fastify.get("/committees/:committee_code", async (request, reply) => {
    const { committee_code } = request.params;

    const committee = await db.knex("bill_committees")
      .where({ committee_code })
      .select("committee_code", "committee_name", "chamber")
      .first();

    if (!committee) {
      reply.code(404);
      return { error: "Committee not found" };
    }

    const bills = await db.knex("bill_committees as bc")
      .join("bills as b", function() {
        this.on("bc.billtype", "=", "b.billtype")
            .andOn("bc.billnumber", "=", "b.billnumber")
            .andOn("bc.congress", "=", "b.congress");
      })
      .where("bc.committee_code", committee_code)
      .select(
        "b.billid", "b.billnumber", "b.billtype", "b.congress",
        "b.shorttitle", "b.officialtitle", "b.introducedat", "b.statusat",
        "b.summary_text", "b.policy_area", "b.latest_action_date",
        db.knex.raw(
          "(SELECT COUNT(*)::int FROM bill_cosponsors cos WHERE cos.billtype = b.billtype AND cos.billnumber = b.billnumber AND cos.congress = b.congress) AS cosponsor_count"
        )
      )
      .orderByRaw("b.latest_action_date DESC NULLS LAST")
      .limit(100);

    return {
      ...committee,
      bills
    };
  });
};
