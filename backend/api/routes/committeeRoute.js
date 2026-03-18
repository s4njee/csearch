const db = require("../controllers/db");

module.exports = async function (fastify, opts) {
  fastify.get("/committees", async (request, reply) => {
    const records = await db.knex("committees as c")
      .join("bill_committees as bc", "bc.committee_code", "c.committee_code")
      .select("c.committee_code", "c.committee_name", "c.chamber")
      .count("* as bill_count")
      .groupBy("c.committee_code", "c.committee_name", "c.chamber")
      .orderBy("c.committee_name", "asc");
      
    return records;
  });

  fastify.get("/committees/:committee_code", async (request, reply) => {
    const { committee_code } = request.params;

    const committee = await db.knex("committees")
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
        "b.billid", db.knex.raw("b.billnumber::text AS billnumber"), "b.billtype", db.knex.raw("b.congress::text AS congress"),
        "b.shorttitle", "b.officialtitle", "b.introducedat", "b.statusat", "b.bill_status",
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
