# CircuitDraft 0.1 Alpha verification

Automated verification on the installed Apple Silicon Mac using Swift 6.3.3. The binary targets macOS 14.0 and later; macOS 14 itself has not been tested.

`./test.sh` completed successfully:

```
PASS: 23 checks (persistence, validation, pin geometry, rendered rotation, BOM/CSV, SVG, undo/redo, PDF)
```

Checks cover editable JSON round trip; rejected empty projects, unknown format versions, invalid pins and unsupported rotations; pin attachment after moving and rotating a symbol; agreement between drawn geometry and model pin transforms; parts aggregation across pages; CSV escaping of quotes, commas and line breaks; SVG text escaping and valid XML; placement, undo, redo and deletion of attached wires; and native PDF output with a PDF header.

`./build.sh` compiled the native arm64 app successfully with the installed Apple toolchain. The app uses no external package dependencies. The build produces an ad hoc signed bundle and a ZIP generated directly from that signed bundle. iCloud Drive may attach Finder metadata to a loose bundle in Documents, so strict signature verification should use an extraction of the ZIP in a local temporary directory or Applications.

Manual native-interface checks passed on the current Mac:

- Launched the app and inspected the complete fitted page, library, page list, toolbar and inspector.
- Selected a contact, rotated it to 90 degrees, and visually verified that its center stayed fixed while connected wires followed its pins.
- Dragged that component from `(540, 240)` to `(540, 430)` and used two undo operations to restore the initial document.
- Switched to the second page, placed a resistor and terminal, and connected them using the wire tool. The saved JSON confirmed that both endpoints referenced the intended component pins.
- Saved through the native save dialog, created a new project, and reopened the saved JSON. Both pages and their symbol/wire counts were restored.
- Opened the parts-list window, confirmed seven placements across two pages, and exported CSV through its save dialog. Python's CSV parser confirmed seven data rows and quantity total seven.
- Extracted the distributable ZIP outside iCloud and passed `codesign --verify --deep --strict`; confirmed the executable is Mach-O arm64 and the bundle plist is valid.

These checks establish the listed CircuitDraft behaviors. They do not establish EPLAN parity, native EPLAN-file interoperability, or suitability for a production electrical design.

## MCP integration verification

The existing 23 model/export checks still pass. `./test-automation.sh` passes 27 additional checks covering all eight native RPC actions, revision conflicts, input rejection without partial mutation, pin movement/rotation, preservation of selection, undo checkpoints, filesystem request/response handling, duplicate request IDs, state snapshots and shutdown.

Real stdio MCP clients successfully initialized both servers, enumerated 13 upstream discovery tools and 11 native companion tools, searched for `eplan_live_place_symbol`, and queried status. The pinned upstream registry contains 220 tools.

A real end-to-end native MCP session added one page, three symbols and two pin-linked wires; rotated a symbol; rejected a stale edit; read the complete project and parts list; and parsed returned SVG. The app visibly displayed the created page and **MCP ready**. The resulting document is `MCP-Demo.circuitdraft.json`. Live Windows EPLAN execution remains untested because no Windows EPLAN host is available.

## Public alpha release check

The v0.1.0-alpha build reran all 23 model/export checks and 27 automation checks successfully. Both MCP stdio servers passed initialization, tool enumeration, catalog search and status calls. The packaged app declares numeric version 0.1.0 and release channel alpha; its ZIP-extracted signature passed strict verification. Native source and public documentation were checked for excluded binaries, runtime state, personal filesystem paths and recognizable secret patterns before publication.
