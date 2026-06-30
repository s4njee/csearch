"""CLI entrypoint for the CSearch MCP server.

  csearch-mcp              # stdio transport (Claude Desktop / Claude Code, local)
  csearch-mcp --http       # streamable HTTP transport (hosted / remote agents)
"""

from __future__ import annotations

import argparse

from .server import API_BASE, mcp


def main() -> None:
    parser = argparse.ArgumentParser(prog="csearch-mcp", description="CSearch MCP server")
    parser.add_argument(
        "--http",
        action="store_true",
        help="Serve over streamable HTTP instead of stdio (for hosting/remote agents).",
    )
    parser.add_argument("--host", default="0.0.0.0", help="HTTP bind host (default 0.0.0.0).")
    parser.add_argument("--port", type=int, default=8000, help="HTTP bind port (default 8000).")
    args = parser.parse_args()

    if args.http:
        mcp.settings.host = args.host
        mcp.settings.port = args.port
        print(f"csearch-mcp: streamable-http on {args.host}:{args.port} -> API {API_BASE}")
        mcp.run(transport="streamable-http")
    else:
        mcp.run()  # stdio


if __name__ == "__main__":
    main()
