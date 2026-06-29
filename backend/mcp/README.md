# CSearch MCP server

A [Model Context Protocol](https://modelcontextprotocol.io) server that exposes U.S.
congressional legislation — bills and roll-call votes, 1973→today — as tools for LLM
agents (Claude Desktop, Claude Code, or any MCP client).

It is a **thin wrapper over the public CSearch API** (`https://api.csearch.org`): it makes
HTTP calls rather than touching the database, so it inherits the API's hybrid retrieval
(keyword + vector), caching, and rate limiting, and can run anywhere.

## Tools

| Tool | What it does |
| --- | --- |
| `semantic_search` | Natural-language hybrid search over bills (best for topic questions) |
| `keyword_search_bills` | Full-text search within a single bill type |
| `latest_bills` | Most recently updated bills of a type |
| `get_bill` | One bill in full (summary, actions, cosponsors, committees, votes) |
| `search_votes` | Search roll-call votes by question text |
| `latest_votes` | Most recent votes for a chamber |
| `get_vote` | One vote in full, including each member's position |
| `data_freshness` | How current the underlying data is |

Every result includes a `csearch.org` URL for citation.

## Configuration

| Env var | Default | Purpose |
| --- | --- | --- |
| `CSEARCH_API_BASE` | `https://api.csearch.org` | CSearch API base URL |
| `CSEARCH_API_TIMEOUT` | `30` | Per-request timeout (seconds) |
| `CSEARCH_SITE_BASE` | `https://csearch.org` | Base for human-readable links |

## Run

Install (with [uv](https://docs.astral.sh/uv/)):

```bash
cd backend/mcp
uv run csearch-mcp            # stdio (local clients)
uv run csearch-mcp --http     # streamable HTTP on :8000 (hosting / remote agents)
```

### Claude Desktop / Claude Code (stdio)

Add to your MCP config (e.g. `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "csearch": {
      "command": "uv",
      "args": ["run", "--directory", "/ABS/PATH/backend/mcp", "csearch-mcp"]
    }
  }
}
```

Then ask, e.g.: *"Use csearch to find recent bills about offshore wind permitting and
summarize the top three."*

### Hosted (streamable HTTP)

```bash
uv run csearch-mcp --http --host 0.0.0.0 --port 8000
# MCP endpoint: http://<host>:8000/mcp
```

Point it at a different backend (e.g. a LAN/dev API) with `CSEARCH_API_BASE`:

```bash
CSEARCH_API_BASE=http://localhost:18080 uv run csearch-mcp
```

## Inspect / debug

```bash
npx @modelcontextprotocol/inspector uv run csearch-mcp
```

## Develop

```bash
uv run --extra dev ruff check .
uv run --extra dev mypy
uv run --extra dev pytest -q
```
