const db = require("../controllers/db");

const CHAMBER_ABBREV = {
  house: "h",
  senate: "s",
  h: "h",
  s: "s",
};
const MIN_FUZZY_QUERY_LENGTH = 3;
const VOTE_FUZZY_SEARCH_EXPR = "concat_ws(' ', coalesce(v.question, ''), coalesce(v.result, ''), coalesce(v.votetype, ''), coalesce(v.chamber, ''))";

function buildVoteSearchWhere(searchQuery, chamber, useFuzzy) {
  const chamberClause = "(? IS NULL OR v.chamber = ?)";
  const exactClause = "v.search_document @@ websearch_to_tsquery('english', ?)";
  const fuzzyClause = useFuzzy ? ` OR lower(${VOTE_FUZZY_SEARCH_EXPR}) % lower(?)` : "";

  return {
    sql: `${chamberClause} AND (${exactClause}${fuzzyClause})`,
    bindings: useFuzzy
      ? [chamber, chamber, searchQuery, searchQuery]
      : [chamber, chamber, searchQuery],
  };
}

module.exports = async function (fastify, opts) {
  fastify.get("/votes/search", async (request, reply) => {
    const { query, chamber } = request.query;
    const searchQuery = String(query || "").trim();
    const useFuzzy = searchQuery.length >= MIN_FUZZY_QUERY_LENGTH;

    if (!searchQuery) {
      reply.code(400);
      return { error: "Missing required query parameter" };
    }

    let normalizedChamber = null;
    if (chamber) {
      normalizedChamber = CHAMBER_ABBREV[String(chamber).toLowerCase()];
      if (!normalizedChamber) {
        reply.code(400);
        return { error: "Invalid chamber; use 'house' or 'senate'" };
      }
    }
    const searchClause = buildVoteSearchWhere(searchQuery, normalizedChamber, useFuzzy);

    const q = db.knex("votes")
      .whereRaw(searchClause.sql, searchClause.bindings)
      .select("voteid", db.knex.raw("congress::text AS congress"), "chamber", "question", "result", "votedate", "votetype")
      .orderByRaw(
        `CASE WHEN v.search_document @@ websearch_to_tsquery('english', ?) THEN 1 ELSE 0 END DESC,
         ts_rank_cd(v.search_document, websearch_to_tsquery('english', ?)) DESC,
         similarity(lower(${VOTE_FUZZY_SEARCH_EXPR}), lower(?)) DESC,
         v.votedate DESC NULLS LAST,
         v.voteid DESC`,
        [searchQuery, searchQuery, searchQuery],
      )
      .limit(20);

    return q;
  });

  fastify.get("/votes/detail/:voteid", async (request, reply) => {
    const { voteid } = request.params;

    const vote = await db.knex("votes")
      .where({ voteid })
      .select(
        "voteid", "bill_type", db.knex.raw("bill_number::text AS bill_number"), db.knex.raw("congress::text AS congress"), db.knex.raw("votenumber::text AS votenumber"),
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
