# Getting Started with [Fastify-CLI](https://www.npmjs.com/package/fastify-cli)
This project was bootstrapped with Fastify-CLI.

## Available Scripts

In the project directory, you can run:

### `npm run dev`

To start the app in dev mode.\
Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

### `npm start`

For production mode

### `npm run test`

Run the test cases.

## Learn More

To learn Fastify, check out the [Fastify documentation](https://www.fastify.io/docs/latest/).

## Explore Queries

`GET /explore` lists the read-only exploratory queries sourced from [sql/explore.sql](./sql/explore.sql), which mirrors the updater query pack.

`GET /explore/:queryId` executes one of those queries and returns its result rows. The `bill-search-example` and `vote-search-example` queries also accept request parameters so callers can use the normalized `search_bills(...)` and `search_votes(...)` helpers with their own search text and limits.
