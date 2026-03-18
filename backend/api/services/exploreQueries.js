"use strict";

const fs = require("fs");
const path = require("path");

const EXPLORE_SQL_PATH = path.join(__dirname, "..", "sql", "explore.sql");
const MAX_RESULT_LIMIT = 100;
const SEARCH_BILLS_QUERY_ID = "bill-search-example";
const SEARCH_VOTES_QUERY_ID = "vote-search-example";
const QUERY_IDS_BY_NUMBER = {
  1: "recent-bills",
  2: "largest-cosponsor-coalitions",
  3: "top-subject-areas",
  4: "active-committees",
  5: "deepest-action-history",
  6: "missing-descriptive-fields",
  7: "largest-vote-margins",
  8: "closest-votes",
  9: "most-not-voting-members",
  10: "broad-sponsorship-history",
  11: SEARCH_BILLS_QUERY_ID,
  12: SEARCH_VOTES_QUERY_ID,
  13: "most-prolific-sponsors",
  14: "bipartisan-bills",
  15: "policy-area-by-congress",
  16: "bills-with-floor-votes",
  17: "party-line-crossovers",
  18: "active-committees-recent",
  19: "closest-votes-recent",
};

const SEARCH_QUERY_PARAMS = {
  [SEARCH_BILLS_QUERY_ID]: [
    { name: "q", type: "string", default: "clean energy tax credit" },
    { name: "billType", type: "string", default: null },
    { name: "congress", type: "integer", default: null },
    { name: "limit", type: "integer", default: 20, min: 1, max: MAX_RESULT_LIMIT },
  ],
  [SEARCH_VOTES_QUERY_ID]: [
    { name: "q", type: "string", default: "cloture nomination" },
    { name: "congress", type: "integer", default: null },
    { name: "chamber", type: "string", default: null },
    { name: "limit", type: "integer", default: 20, min: 1, max: MAX_RESULT_LIMIT },
  ],
};

let cachedQueries;

function slugifyTitle(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function finalizeQuery(queries, currentQuery) {
  if (!currentQuery) {
    return;
  }

  const sql = currentQuery.lines.join("\n").trim();
  if (!sql) {
    return;
  }

  const id = QUERY_IDS_BY_NUMBER[currentQuery.number] || slugifyTitle(currentQuery.title);
  queries.push({
    id,
    number: currentQuery.number,
    title: currentQuery.title,
    sql,
    parameters: SEARCH_QUERY_PARAMS[id] || [],
  });
}

function parseExploreQueries(sqlText) {
  const queries = [];
  const lines = sqlText.split(/\r?\n/);
  let currentQuery = null;

  for (const line of lines) {
    const headerMatch = line.match(/^--\s+(\d+)\.\s+(.*)$/);
    if (headerMatch) {
      finalizeQuery(queries, currentQuery);
      currentQuery = {
        number: Number.parseInt(headerMatch[1], 10),
        title: headerMatch[2].trim(),
        lines: [],
      };
      continue;
    }

    if (!currentQuery) {
      continue;
    }

    currentQuery.lines.push(line);
  }

  finalizeQuery(queries, currentQuery);
  return queries;
}

function loadExploreQueries() {
  if (!cachedQueries) {
    const sqlText = fs.readFileSync(EXPLORE_SQL_PATH, "utf8");
    cachedQueries = parseExploreQueries(sqlText);
  }

  return cachedQueries;
}

function normalizeOptionalText(value) {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  return String(value);
}

function normalizeOptionalInteger(value) {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    return null;
  }

  return parsed;
}

function normalizeLimit(value, defaultValue) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    return defaultValue;
  }

  if (parsed < 1) {
    return 1;
  }

  return Math.min(parsed, MAX_RESULT_LIMIT);
}

function getExploreQueries() {
  return loadExploreQueries().map((query) => ({
    id: query.id,
    number: query.number,
    title: query.title,
    path: `/explore/${query.id}`,
    parameters: query.parameters,
  }));
}

function getExploreQuery(queryId) {
  return loadExploreQueries().find((query) => query.id === queryId) || null;
}

function buildExecution(query, requestQuery = {}) {
  if (query.id === SEARCH_BILLS_QUERY_ID) {
    return {
        sql: "SELECT * FROM search_bills(?, ?, ?, ?);",
        bindings: [
        requestQuery.q || "clean energy tax credit",
        normalizeOptionalText(requestQuery.billType),
        normalizeOptionalInteger(requestQuery.congress),
        normalizeLimit(requestQuery.limit, 20),
      ],
    };
  }

  if (query.id === SEARCH_VOTES_QUERY_ID) {
    return {
      sql: "SELECT * FROM search_votes(?, ?, ?, ?);",
      bindings: [
        requestQuery.q || "cloture nomination",
        normalizeOptionalInteger(requestQuery.congress),
        normalizeOptionalText(requestQuery.chamber),
        normalizeLimit(requestQuery.limit, 20),
      ],
    };
  }

  return {
    sql: query.sql,
    bindings: [],
  };
}

async function executeExploreQuery(knex, queryId, requestQuery) {
  const query = getExploreQuery(queryId);
  if (!query) {
    return null;
  }

  const execution = buildExecution(query, requestQuery);
  const result = await knex.raw(execution.sql, execution.bindings);

  return {
    query: {
      id: query.id,
      number: query.number,
      title: query.title,
      parameters: query.parameters,
    },
    sql: execution.sql,
    bindings: execution.bindings,
    rows: result.rows,
  };
}

module.exports = {
  executeExploreQuery,
  getExploreQueries,
  getExploreQuery,
};
