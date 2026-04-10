const db = require("../controllers/db");
const { VALID_BILL_TYPES } = require("../utils/constants");

const BILL_LIST_COLUMNS = [
  "b.billid", "b.shorttitle", "b.officialtitle", "b.introducedat",
  "b.summary_text", "b.billtype",
  db.knex.raw("b.congress::text AS congress"),
  db.knex.raw("b.billnumber::text AS billnumber"),
  "b.sponsor_name", "b.sponsor_party", "b.sponsor_state", "b.sponsor_bioguide_id",
  "b.bill_status", "b.statusat", "b.policy_area", "b.latest_action_date", "b.origin_chamber",
];
const MIN_FUZZY_QUERY_LENGTH = 3;
const BILL_FUZZY_SEARCH_EXPR = "concat_ws(' ', coalesce(b.shorttitle, ''), coalesce(b.officialtitle, ''), coalesce(b.sponsor_name, ''), coalesce(b.policy_area, ''))";
const BILL_COMMITTEE_CODES = db.knex.raw(
  "(SELECT COALESCE(array_agg(DISTINCT bc.committee_code ORDER BY bc.committee_code), '{}') FROM bill_committees bc WHERE bc.billtype = b.billtype AND bc.billnumber = b.billnumber AND bc.congress = b.congress) AS committee_codes"
);

function buildBillSearchWhere(table, searchQuery, useFuzzy) {
  const tableClause = "(? = 'all' OR b.billtype = ?)";
  const exactClause = "b.search_document @@ websearch_to_tsquery('english', ?)";
  const fuzzyClause = useFuzzy ? ` OR lower(${BILL_FUZZY_SEARCH_EXPR}) % lower(?)` : "";

  return {
    sql: `${tableClause} AND (${exactClause}${fuzzyClause})`,
    bindings: useFuzzy
      ? [table, table, searchQuery, searchQuery]
      : [table, table, searchQuery],
  };
}

module.exports = async function (fastify, opts) {
  fastify.get("/search/:table/:filter", async (request, reply) => {
    const { table, filter } = request.params;
    const { query } = request.query;
    const searchQuery = String(query || "").trim();
    const useFuzzy = searchQuery.length >= MIN_FUZZY_QUERY_LENGTH;

    if (table !== "all" && !VALID_BILL_TYPES.has(table)) {
      reply.code(400);
      return { error: "Invalid bill type" };
    }

    if (!searchQuery) {
      reply.code(400);
      return { error: "Missing required query parameter" };
    }

    const cosponsorCount = db.knex.raw(
      "(SELECT COUNT(*)::int FROM bill_cosponsors bc WHERE bc.billtype = b.billtype AND bc.billnumber = b.billnumber AND bc.congress = b.congress) AS cosponsor_count"
    );
    const searchClause = buildBillSearchWhere(table, searchQuery, useFuzzy);

    const baseQuery = (orderBy, bindings) => {
      const q = db.knex
        .select([...BILL_LIST_COLUMNS, BILL_COMMITTEE_CODES, cosponsorCount])
        .from("bills as b")
        .whereRaw(searchClause.sql, searchClause.bindings);
      return q.orderByRaw(orderBy, bindings).limit(30);
    };

    if (filter === "relevance") {
      const results = await baseQuery(
        `CASE WHEN b.search_document @@ websearch_to_tsquery('english', ?) THEN 1 ELSE 0 END DESC,
         ts_rank_cd(b.search_document, websearch_to_tsquery('english', ?)) DESC,
         similarity(lower(${BILL_FUZZY_SEARCH_EXPR}), lower(?)) DESC,
         b.statusat DESC NULLS LAST,
         b.billtype,
         b.billnumber`,
        [searchQuery, searchQuery, searchQuery],
      );
      request.log.info({
        query: searchQuery,
        table,
        filter,
        clientIp: request.ip,
        resultCount: results.length
      }, 'search executed')
      return results
    }

    if (filter === "date") {
      const results = await baseQuery(
        `b.statusat DESC NULLS LAST,
         similarity(lower(${BILL_FUZZY_SEARCH_EXPR}), lower(?)) DESC,
         b.billtype,
         b.billnumber`,
        [searchQuery],
      );
      request.log.info({
        query: searchQuery,
        table,
        filter,
        clientIp: request.ip,
        resultCount: results.length
      }, 'search executed')
      return results
    }

    reply.code(400);
    return { error: "Invalid filter; use 'relevance' or 'date'" };
  });
};
