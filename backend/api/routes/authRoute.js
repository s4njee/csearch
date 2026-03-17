const oauthPlugin = require("@fastify/oauth2");
const db = require("../controllers/db");

module.exports = async function (fastify, opts) {
  fastify.register(oauthPlugin, {
    name: "googleOAuth2",
    scope: ["profile", "email"],
    credentials: {
      client: {
        id: process.env.GOOGLE_CLIENT_ID,
        secret: process.env.GOOGLE_CLIENT_SECRET,
      },
      auth: oauthPlugin.GOOGLE_CONFIGURATION,
    },
    startRedirectPath: "/login",
    callbackUri: "https://csearch.org",
    callbackUriParams: {
      access_type: "offline",
    },
  });

  fastify.decorate("authenticate", async function (request, reply) {
    try {
      await request.jwtVerify();
    } catch (err) {
      reply.send(err);
    }
  });

  fastify.post("/login", async function (request, reply) {
    const data = request.body;
    const rows = await db.knex.raw(
      "select exists(select 1 from users where email= ? )",
      data.email
    );

    if (rows.rows[0].exists === false) {
      await db.knex("users").insert({
        email: data.email,
        firstname: data.given_name,
        lastname: data.family_name,
      });
    }

    const token = fastify.jwt.sign({ email: data.email });
    return JSON.stringify({ user: data.email, token });
  });

  fastify.post(
    "/addVote",
    { onRequest: [fastify.authenticate] },
    async function (request, reply) {
      const body = request.body;
      const rows = await db.knex
        .select("votes")
        .from("bills")
        .where("billid", body.billid);

      const votes = rows[0]?.votes || [];
      if (!votes.includes(body.email)) {
        await db.knex.raw(
          `UPDATE bills SET votes = (
            CASE WHEN votes IS NULL THEN '[]'::JSONB ELSE votes END
          ) || ?::JSONB WHERE billid = ?;`,
          [`["${body.email}"]`, body.billid]
        );
        await db.knex.raw(
          `UPDATE bills SET votecount = votecount + 1 WHERE billid = ?;`,
          [body.billid]
        );
      }

      return { ok: true };
    }
  );

  fastify.post(
    "/removeVote",
    { onRequest: [fastify.authenticate] },
    async function (request, reply) {
      const body = request.body;
      const rows = await db.knex("bills")
        .select("votes")
        .where("billid", body.billid);

      const votes = rows[0]?.votes;
      if (votes && votes.includes(body.email)) {
        await db.knex.raw(
          `UPDATE bills SET votes = votes - ?::text WHERE billid = ?;`,
          [body.email, body.billid]
        );
        await db.knex.raw(
          `UPDATE bills SET votecount = GREATEST(votecount - 1, 0) WHERE billid = ?;`,
          [body.billid]
        );
      }

      return { ok: true };
    }
  );
};
