"use strict";

const db = require("../controllers/db");
const cache = require("../utils/cache");
const {
  executeExploreQuery,
  getExploreQueries,
} = require("../services/exploreQueries");

module.exports = async function (fastify) {
  fastify.get("/explore", async function () {
    return { queries: getExploreQueries() };
  });

  fastify.get("/explore/:queryId", async function (request, reply) {
    const { queryId } = request.params;
    
    // Sort query keys to ensure consistent cache keys
    const queryParamsString = Object.keys(request.query)
      .sort()
      .map(k => `${k}=${request.query[k]}`)
      .join('&');
    const cacheKey = `explore_${queryId}_${queryParamsString}`;

    if (cache.has(cacheKey)) {
      reply.header("X-Cache", "HIT");
      return cache.get(cacheKey);
    }

    const result = await executeExploreQuery(
      db.knex,
      queryId,
      request.query
    );

    if (!result) {
      reply.code(404);
      return {
        error: "Not Found",
        message: `Unknown explore query: ${queryId}`,
      };
    }

    const response = {
      query: result.query,
      sql: result.sql,
      bindings: result.bindings,
      results: result.rows,
    };

    cache.set(cacheKey, response);
    reply.header("X-Cache", "MISS");
    return response;
  });
};
