"""Native CircuitDraft automation over MCP, plus pinned upstream discovery.

No EPLAN DLL is loaded. The Swift app performs edits on its main thread and
retains undo history. Native and EPLAN tools use separate namespaces.
"""
import contextlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

from mcp.server.fastmcp import FastMCP

ROOT = Path(__file__).resolve().parent.parent
AUTOMATION = Path(os.environ.get("CIRCUITDRAFT_AUTOMATION_DIR",
                               Path.home() / "Library/Application Support/CircuitDraft/Automation"))
UPSTREAM = Path(__file__).parent / "third_party/eplan-mcp/mcp_server"
os.environ.setdefault("EPLAN_MCP_MODE", "discovery")
sys.path.insert(0, str(UPSTREAM))
with contextlib.redirect_stdout(sys.stderr):
    import server as eplan_upstream

mcp = FastMCP("CircuitDraft Mac")


def app_state() -> dict:
    try:
        state = json.loads((AUTOMATION / "State.json").read_text())
        pid = int(state["pid"])
        command = subprocess.check_output(["/bin/ps", "-p", str(pid), "-o", "comm="],
                                          text=True, stderr=subprocess.DEVNULL).strip()
        if not command.endswith("/CircuitDraft") or not state.get("running"):
            raise ValueError("CircuitDraft process is no longer running")
        return state
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError):
        return {"running": False, "automation_dir": str(AUTOMATION),
                "message": "Open the updated CircuitDraft.app to enable native automation."}


def rpc(action: str, arguments: dict | None = None, expected_revision: int | None = None) -> dict:
    if not app_state().get("running"):
        return {"success": False, "error": "CircuitDraft is not running with this automation directory.",
                "automation_dir": str(AUTOMATION)}
    request_id = str(uuid.uuid4())
    request = {"id": request_id, "action": action, "arguments": arguments or {}}
    if expected_revision is not None:
        request["expectedRevision"] = expected_revision
    pending = AUTOMATION / "Requests" / (request_id + ".json")
    response = AUTOMATION / "Responses" / (request_id + ".json")
    pending.parent.mkdir(parents=True, exist_ok=True)
    response.parent.mkdir(parents=True, exist_ok=True)
    temporary = pending.with_suffix(".tmp")
    temporary.write_text(json.dumps(request, allow_nan=False))
    temporary.replace(pending)
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        try:
            result = json.loads(response.read_text())
            if result.get("id") != request_id:
                raise ValueError("Mismatched automation response")
            response.unlink(missing_ok=True)
            return result
        except FileNotFoundError:
            time.sleep(0.05)
    return {"success": False, "request_id": request_id, "outcome": "unknown",
            "error": "Timed out waiting for the app. Do not repeat an edit blindly; inspect request_result."}


@mcp.tool()
def circuitdraft_status() -> dict:
    """Check whether the native Mac app is running and report its current revision."""
    state = app_state()
    if not state.get("running"):
        return state
    return rpc("status")


@mcp.tool()
def circuitdraft_get_project() -> dict:
    """Read the running Mac app's complete editable project and selected page."""
    return rpc("get_project")


@mcp.tool()
def circuitdraft_add_page(name: str, expected_revision: int | None = None) -> dict:
    """Add a page to the native project. Supply expected_revision to reject stale edits."""
    return rpc("add_page", {"name": name}, expected_revision)


@mcp.tool()
def circuitdraft_add_symbol(kind: str, x: float, y: float, tag: str | None = None,
                           description: str = "", part: str = "", manufacturer: str = "",
                           page_id: str | None = None, expected_revision: int | None = None) -> dict:
    """Place a native symbol: resistor, contact, coil, terminal, fuse, motor, or ground.

    Coordinates use CircuitDraft drawing units and its 10-unit grid, not EPLAN millimetres.
    """
    args = {"kind": kind, "x": x, "y": y, "description": description,
            "part": part, "manufacturer": manufacturer}
    if tag is not None:
        args["tag"] = tag
    if page_id is not None:
        args["page_id"] = page_id
    return rpc("add_symbol", args, expected_revision)


@mcp.tool()
def circuitdraft_connect_pins(start_component_id: str, start_pin: int,
                             end_component_id: str, end_pin: int,
                             page_id: str | None = None, expected_revision: int | None = None) -> dict:
    """Connect two pins on a native page. Pins are zero-based and remain attached on moves."""
    args = {"start_component_id": start_component_id, "start_pin": start_pin,
            "end_component_id": end_component_id, "end_pin": end_pin}
    if page_id is not None:
        args["page_id"] = page_id
    return rpc("connect_pins", args, expected_revision)


@mcp.tool()
def circuitdraft_update_symbol(component_id: str, tag: str | None = None,
                              description: str | None = None, part: str | None = None,
                              manufacturer: str | None = None, x: float | None = None,
                              y: float | None = None, rotation: int | None = None,
                              page_id: str | None = None, expected_revision: int | None = None) -> dict:
    """Edit native symbol properties/position/rotation with undo support; rotation is 0/90/180/270."""
    args = {key: value for key, value in locals().items()
            if value is not None and key != "expected_revision"}
    return rpc("update_symbol", args, expected_revision)


@mcp.tool()
def circuitdraft_parts_list() -> dict:
    """Read the native project's grouped parts list across all pages."""
    return rpc("parts_list")


@mcp.tool()
def circuitdraft_export_svg(page_id: str | None = None) -> dict:
    """Return a native page as SVG text without opening a save dialog or writing a file."""
    return rpc("export_svg", {"page_id": page_id} if page_id else {})


@mcp.tool()
def circuitdraft_eplan_tools_search(query: str, limit: int = 10) -> dict:
    """Search the pinned Canary-ECAD EPLAN tool definitions offline on Mac.

    Results describe the upstream Windows EPLAN API; they do not imply the
    named feature is implemented in CircuitDraft. No EPLAN connection is made.
    """
    result = eplan_upstream.REGISTRY.search(query, max(1, min(limit, 50)))
    result["execution_backend"] = "Windows EPLAN required; discovery only on this Mac"
    result["upstream_commit"] = "0681c75cb5c2d75cbb6ca0db5e83625fdb1c6f4d"
    return result


@mcp.tool()
def circuitdraft_eplan_tools_describe(names: list[str]) -> dict:
    """Read upstream EPLAN tool parameters offline; these tools are not native Mac implementations."""
    return eplan_upstream.REGISTRY.describe(names)


@mcp.tool()
def circuitdraft_request_result(request_id: str) -> dict:
    """Inspect a timed-out request without repeating a potentially completed edit."""
    identifier = str(uuid.UUID(request_id))
    path = AUTOMATION / "Responses" / (identifier + ".json")
    if path.exists():
        return json.loads(path.read_text())
    return {"request_id": identifier, "outcome": "unknown",
            "pending": (AUTOMATION / "Requests" / (identifier + ".json")).exists()}


if __name__ == "__main__":
    mcp.run(transport="stdio")
