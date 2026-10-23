"""Launch the pinned upstream MCP server without contaminating stdio framing."""
import contextlib
import os
from pathlib import Path
import sys

UPSTREAM = Path(__file__).parent / "third_party/eplan-mcp/mcp_server"
os.environ.setdefault("EPLAN_MCP_MODE", "discovery")
sys.path.insert(0, str(UPSTREAM))
with contextlib.redirect_stdout(sys.stderr):
    import server

if __name__ == "__main__":
    print(f"EPLAN upstream: {len(server.REGISTRY)} tools; "
          f"{len(server.REGISTRY.published_names())} published. "
          "On macOS, discovery works; live EPLAN requires a Windows host.", file=sys.stderr)
    server.mcp.run(transport="stdio")
