"""Exercise real MCP initialize/list/call over stdio; no EPLAN or native edits."""
import asyncio
import json
from pathlib import Path
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

HERE = Path(__file__).resolve().parent


async def inspect(name, minimum, search_tool, status_tool):
    parameters = StdioServerParameters(command=sys.executable, args=[str(HERE / name)])
    async with stdio_client(parameters) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            listing = await session.list_tools()
            names = [tool.name for tool in listing.tools]
            assert len(names) >= minimum, names
            result = await session.call_tool(search_tool, {"query": "live_place_symbol", "limit": 5})
            assert not result.isError, result
            data = json.loads(result.content[0].text)
            assert data["success"] and any(t["name"] == "eplan_live_place_symbol" for t in data["tools"]), data
            status = await session.call_tool(status_tool, {})
            assert not status.isError, status
            print(json.dumps({"server": name, "protocol": "initialize/list_tools/call_tool passed",
                              "tool_count": len(names), "status": json.loads(status.content[0].text)}))


async def main():
    await inspect("eplan_server.py", 13, "eplan_tools_search", "eplan_status")
    await inspect("circuitdraft_server.py", 11, "circuitdraft_eplan_tools_search", "circuitdraft_status")


if __name__ == "__main__":
    asyncio.run(main())
