# EPLAN MCP and native CircuitDraft automation

Added from [Canary-ECAD/eplan-mcp](https://github.com/Canary-ECAD/eplan-mcp) at commit `0681c75cb5c2d75cbb6ca0db5e83625fdb1c6f4d` on 2026-10-23. The included `third_party/eplan-mcp/mcp_server` is an unmodified snapshot of the upstream server directory. Its MIT license and copyright notice are preserved alongside it. The adapters outside `third_party` are new CircuitDraft integration code.

## Available capabilities

| Codex MCP server | Available capability | Limit |
| --- | --- | --- |
| `eplan` | Starts the upstream server in discovery mode: 13 published tools indexing 220 registered tools in this pinned checkout. Tool search, parameter descriptions and disconnected status work without EPLAN. | Live actions still need EPLAN and its Windows API runtime. Registering the tools does not port EPLAN. |
| `circuitdraft` | 11 MCP tools controlling the running native app and searching the upstream catalog. | Implements the listed native operations only; no EPLAN project-file support or full action equivalence. |

The source README's advertised count differs from this checkout's runtime count. The 220/13 counts above were measured by importing its registry and performing an actual MCP handshake.

## Native tools

- `circuitdraft_status`, `circuitdraft_get_project`
- `circuitdraft_add_page`, `circuitdraft_add_symbol`, `circuitdraft_connect_pins`, `circuitdraft_update_symbol`
- `circuitdraft_parts_list`, `circuitdraft_export_svg`
- `circuitdraft_eplan_tools_search`, `circuitdraft_eplan_tools_describe`
- `circuitdraft_request_result` for resolving a timed-out edit without repeating it

Native edits run in the Swift app, use its validation and undo stack, and immediately appear in the interface. Coordinates are CircuitDraft drawing units on a 10-unit grid, not EPLAN millimetres. Pin indices are zero-based. Mutating calls accept `expected_revision`; use the revision returned by the previous read/edit to reject concurrent stale edits.

The native bridge uses local JSON request/response files in `~/Library/Application Support/CircuitDraft/Automation`. It opens no network listener. The app displays **MCP ready** when the bridge is active. `CIRCUITDRAFT_AUTOMATION_DIR` can override the directory, but both the app and server must use the same value. These runtime files include the current project and are not source-package content.

Example agent request after loading both MCP servers:

> In CircuitDraft, read the current project and revision. Add a new control-circuit page, place a fuse, contact and coil, connect their pins, then show the parts list. Use expected_revision for each edit.

`MCP-Demo.circuitdraft.json` in the project root was produced by a real end-to-end MCP session performing this workflow.

## Install and register the optional servers

The companion requires **Python 3.10 or later**. From this folder, run `./setup.sh` to create `Integrations/.venv`. If your default `python3` is older, choose a suitable interpreter explicitly, for example `CIRCUITDRAFT_PYTHON=python3.12 ./setup.sh`.

Then register each adapter using your checkout's absolute paths:

```sh
codex mcp add eplan --env EPLAN_MCP_MODE=discovery -- /absolute/path/Integrations/.venv/bin/python /absolute/path/Integrations/eplan_server.py
codex mcp add circuitdraft -- /absolute/path/Integrations/.venv/bin/python /absolute/path/Integrations/circuitdraft_server.py
```

Restart Codex to load the new tools. Open CircuitDraft to use native editing tools. Registration alone does not establish a working connection: run the protocol test below to verify startup and discovery in your environment. No credentials are required for the local stdio servers.

The dependency lock pins MCP SDK **1.30.0**. Upstream declares `mcp>=1.8.0`; that unconstrained range currently selects SDK 2.x, which removed its `mcp.server.fastmcp` import. The isolated environment uses the compatible v1 API without modifying upstream source or the global Python installation.

Run `python test_mcp.py` with that environment for actual stdio initialization, tool enumeration, upstream catalog search and status checks. This protocol test does not edit a project. `../test-automation.sh` checks the Swift RPC implementation with temporary state directories.

## Connecting real Windows EPLAN later

The upstream server must run on the Windows machine that has EPLAN installed. Its actions exchange generated script/result files through local paths; setting only a remote EPLAN host on this Mac does not provide a complete working topology.

The upstream server supports Streamable HTTP. Run it on the EPLAN machine bound to `127.0.0.1`, keep an SSH tunnel to its port, and register the tunneled `/mcp` URL in Codex. Its HTTP listener has no built-in authentication, so the loopback/tunnel topology is part of that setup. No Windows host was provided here; no live EPLAN connection or project mutation was attempted.

Remote documentation RAG services and symbol datasets are not enabled by these adapters. The alpha does not attempt to connect to a Windows host automatically.
