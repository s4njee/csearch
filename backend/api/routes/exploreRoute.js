"use strict";

const db = require("../controllers/db");
const {
  executeExploreQuery,
  getExploreQueries,
} = require("../services/exploreQueries");

module.exports = async function (fastify) {
  fastify.get("/explore", async function () {
    return { queries: getExploreQueries() };
  });

  fastify.get("/explore/:queryId", async function (request, reply) {
    const result = await executeExploreQuery(
      db.knex,
      request.params.queryId,
      request.query
    );

    if (!result) {
      reply.code(404);
      return {
        error: "Not Found",
        message: `Unknown explore query: ${request.params.queryId}`,
      };
    }

    return {
      query: result.query,
      sql: result.sql,
      bindings: result.bindings,
      results: result.rows,
    };
  });
};
