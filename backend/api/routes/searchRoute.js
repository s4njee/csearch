const db = require("../controllers/db");
const { VALID_BILL_TYPES } = require("../utils/constants");

const BILL_LIST_COLUMNS = [
  "b.billid", "b.shorttitle", "b.officialtitle", "b.introducedat",
  "b.summary_text", "b.billtype", "b.congress", "b.billnumber",
  "b.sponsor_name", "b.sponsor_party", "b.sponsor_state", "b.sponsor_bioguide_id",
  "b.statusat", "b.policy_area", "b.latest_action_date", "b.origin_chamber",
];

module.exports = async function (fastify, opts) {
  fastify.get("/search/:table/:filter", async (request, reply) => {
    const { table, filter } = request.params;
    const { query } = request.query;

    if (!VALID_BILL_TYPES.has(table)) {
      reply.code(400);
      return { error: "Invalid bill type" };
    }

    if (!query || !query.trim()) {
      reply.code(400);
      return { error: "Missing required query parameter" };
    }

    const cosponsorCount = db.knex.raw(
      "(SELECT COUNT(*)::int FROM bill_cosponsors bc WHERE bc.billtype = b.billtype AND bc.billnumber = b.billnumber AND bc.congress = b.congress) AS cosponsor_count"
    );

    if (filter === "relevance") {
      return db.knex
        .select([...BILL_LIST_COLUMNS, cosponsorCount])
        .from("bills as b")
        .where("b.billtype", table)
        .whereRaw("b.search_document @@ websearch_to_tsquery('english', ?)", [query])
        .orderByRaw("ts_rank_cd(b.search_document, websearch_to_tsquery('english', ?)) desc", [query])
        .limit(30);
    }

    if (filter === "date") {
      return db.knex
        .select([...BILL_LIST_COLUMNS, cosponsorCount])
        .from("bills as b")
        .where("b.billtype", table)
        .whereRaw("b.search_document @@ websearch_to_tsquery('english', ?)", [query])
        .orderBy("b.statusat", "desc")
        .limit(30);
    }

    reply.code(400);
    return { error: "Invalid filter; use 'relevance' or 'date'" };
  });
};
