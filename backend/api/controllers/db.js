require("dotenv").config();

const host = process.env.POSTGRESURI || "localhost";
const user = process.env.DB_USER || "postgres";
const password = process.env.DB_PASSWORD || "postgres";
const database = process.env.DB_NAME || "csearch";
const port = parseInt(process.env.DB_PORT || "5432", 10);

const knex = require("knex")({
  client: "pg",
  connection: {
    host,
    port,
    user,
    password,
    database,
    ssl: false,
  },
});

module.exports = { knex };
