const db = require("../controllers/db");

module.exports = async function (fastify, opts) {
  fastify.get("/votes/detail/:voteid", async (request, reply) => {
    const { voteid } = request.params;

    const vote = await db.knex("votes")
      .where({ voteid })
      .select(
        "voteid", "bill_type", "bill_number", "congress", "votenumber",
        "votedate", "question", "result", "votesession", "chamber",
        "source_url", "votetype"
      )
      .first();

    if (!vote) {
      reply.code(404);
      return { error: "Vote not found" };
    }

    const members = await db.knex("vote_members")
      .where({ voteid })
      .select("bioguide_id", "display_name", "party", "state", "position")
      .orderBy("display_name", "asc");

    return { ...vote, members };
  });
};
