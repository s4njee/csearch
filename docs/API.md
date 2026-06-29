# CSearch Public API

Read-only HTTP API for U.S. congressional data — bills, roll-call votes, members,
committees, representatives, and pgvector-backed **hybrid semantic search**
(keyword + vector via Reciprocal Rank Fusion).

- **Base URL:** `https://api.csearch.org`
- **Interactive docs:** <https://api.csearch.org/docs> · **OpenAPI:** <https://api.csearch.org/openapi.json>
- **Auth:** none — open, CORS-enabled, read-only
- **Versioning:** data endpoints are served under `/v1`
- **Rate limits:** semantic search is rate-limited per client IP

## Endpoints

| Method & path | Description |
| --- | --- |
| `GET /v1/latest/{billtype}` | Most recently updated bills of a type (`hr`, `s`, …) |
| `GET /v1/search/{billtype}/{sort}` | Keyword search within a type; `sort` = `relevance`\|`date` |
| `GET /v1/bills/{billtype}/{congress}/{billnumber}` | Full bill detail (actions, cosponsors, committees, votes) |
| `GET /v1/bills/bynumber/{number}` | Bills by raw number across types |
| `POST /v1/search/semantic` | Hybrid (keyword + vector) semantic search |
| `GET /v1/search/semantic/coverage` | Semantic index coverage stats |
| `GET /v1/votes/{chamber}` | Recent votes (`house`\|`senate`) |
| `GET /v1/votes/search` | Search votes by question text |
| `GET /v1/votes/detail/{voteid}` | Full vote detail incl. member positions |
| `GET /v1/explore` | Prebuilt exploratory queries |
| `GET /freshness` | Data recency + totals |
| `GET /health` · `GET /livez` · `GET /readyz` | Health checks |

## Examples

Hybrid semantic search:

```bash
curl -s https://api.csearch.org/v1/search/semantic \
  -H 'content-type: application/json' \
  -d '{"query": "offshore wind permitting", "limit": 5}'
```

Bill detail:

```bash
curl -s https://api.csearch.org/v1/bills/hr/119/9495
```

Recent Senate votes:

```bash
curl -s 'https://api.csearch.org/v1/votes/senate?limit=10'
```

## Errors

Errors return a JSON body with a message and a standard HTTP status code
(`400` invalid, `404` not found, `413` query too long, `429` rate limited,
`503` unavailable). See `/docs` for the exact response schema per endpoint.

## MCP server (for LLM agents)

An MCP server that wraps this API — exposing `semantic_search`, `get_bill`,
`search_votes`, `get_vote`, and more as tools for Claude and other MCP clients —
lives in [`backend/mcp`](../backend/mcp/). See its
[README](../backend/mcp/README.md) for stdio (Claude Desktop / Claude Code) and
hosted streamable-HTTP setup.
