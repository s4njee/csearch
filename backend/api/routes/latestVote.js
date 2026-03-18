const db = require("../controllers/db");
const cache = require("../utils/cache");

const CHAMBER_ABBREV = { house: "h", senate: "s" };

module.exports = async function (fastify, opts) {
  fastify.get("/votes/:chamber", async (request, reply) => {
    const { chamber } = request.params;

    if (!CHAMBER_ABBREV[chamber]) {
      reply.code(400);
      return { error: "Invalid chamber; use 'house' or 'senate'" };
    }

    const cacheKey = `latest_votes_${chamber}`;
    if (cache.has(cacheKey)) {
      reply.header("X-Cache", "HIT");
      return cache.get(cacheKey);
    }

    const data = await db.knex
      .select(
        db.knex.raw("v.congress::text AS congress"), db.knex.raw("v.votenumber::text AS votenumber"), "v.votedate", "v.question",
        "v.votesession", "v.result", "v.chamber", "v.votetype",
        "v.voteid", "v.source_url",
        db.knex.raw("COUNT(CASE WHEN vm.position = 'yea'       THEN 1 END)::int AS yea"),
        db.knex.raw("COUNT(CASE WHEN vm.position = 'nay'       THEN 1 END)::int AS nay"),
        db.knex.raw("COUNT(CASE WHEN vm.position = 'present'   THEN 1 END)::int AS present"),
        db.knex.raw("COUNT(CASE WHEN vm.position = 'notvoting' THEN 1 END)::int AS notvoting")
      )
      .from("votes as v")
      .leftJoin("vote_members as vm", "vm.voteid", "v.voteid")
      .whereRaw("v.votedate::date between current_date - 90 and current_date")
      .where("v.chamber", CHAMBER_ABBREV[chamber])
      .groupBy(
        "v.voteid", "v.congress", "v.votenumber", "v.votedate", "v.question",
        "v.votesession", "v.result", "v.chamber", "v.votetype", "v.source_url"
      )
      .orderBy("v.votedate", "desc")
      .limit(60);

    cache.set(cacheKey, data);
    reply.header("X-Cache", "MISS");
    return data;
  });
};
