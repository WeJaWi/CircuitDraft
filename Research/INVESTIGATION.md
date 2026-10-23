# EPLAN Education 2027: Mac reconstruction investigation

Investigation date: 2026-10-23. Requested first milestone: electrical schematics, symbols, wires, pages, and parts lists. The v0.1.0-alpha publication contains original source, community integration code and these summary notes; proprietary reference artifacts are excluded.

## Result and scope

CircuitDraft is an original native macOS implementation of that first milestone. It is an early reconstruction of a useful schematic workflow, not a port of the EPLAN binary, a complete EPLAN replacement, or an implementation of EPLAN's proprietary project format. Its behavior is a design choice unless this report explicitly identifies supporting package evidence. No EPLAN code, binaries, symbol libraries, or visual assets are included in the application.

## Evidence and findings

| Question | Result | Evidence and boundary |
| --- | --- | --- |
| What was supplied? | Windows installation distribution for EPLAN Education and Platform 2027, plus license client, education data, and setup tools. | ZIP member inventory; REA manifest `agm_9c2c293c358ff798d16da44467953d0eaf4d948f23130cadde43b63c2b3e8271`. |
| Which version and CPU? | Setup metadata declares `2027.0.3.27418`, target `x64`. Selected application binaries have PE machine `0x8664`. | `Platform/setup.xml`, `Education/setup.xml`, and directly decoded PE headers. Installer declarations do not establish runtime correctness. |
| Is the core a portable .NET application? | The sampled data-model API is mixed C++/CLI x64, targets .NET 8, and depends on Windows. The main executable is native PE with no CLI directory. | REA IDs below; runtime JSON explicitly names `Microsoft.WindowsDesktop.App` 8.0.0. |
| What ties the editor to Windows? | Sampled editor modules import MFC, GDI/GDI+, USER32, COM, and numerous native EPLAN libraries. | `PE-DEPENDENCIES.json`, read from file-backed PE import descriptors. Imports show linkage, not which paths execute. |
| What domain concepts can be established? | Bundled API documentation describes projects containing pages, placements and symbols, logical device functions, connections and part references. | `DOMAIN-MAP.md`; supplied XML API documentation parsed as data. This is API contract evidence, not observed UI behavior. |
| Can EPLAN files be read or written? | Unresolved. No project-format decoder or compatibility claim has been established. | Installer contents are not sample user projects; project storage has not been traced and round-trip tested. |
| Was EPLAN run? | No. | Original Windows application execution and behavioral comparison are outside the evidence collected so far. |
| Is complete feature parity achieved? | No. | PLC engineering, terminal/cable management, reports, macros, 3D/panel engineering, vendor catalogs, interoperability, and many other workflows remain outside this first milestone. |

The platform MSI's embedded cabinet lists 8,058 entries, totaling 4,665,993,936 uncompressed bytes. This is the cabinet inventory, including resources and configuration, not a count of application modules. Selective extraction avoided installing the Windows package.

## Artifact identities

Original ZIP SHA-256:

`c0253b17db25c19c56a79125d6bad81dbd75c9575231549acb207d1191785527`

Selected executable SHA-256:

`65b677eb24a47deb513be5d4a858ceb60cbbdf75c7ce05708e300aabd7e9bd7a`

`PE-DEPENDENCIES.json` records additional selected file identities and imports. Cabinet member names have installer prefixes and are not asserted to be installed filenames.

## REA evidence ledger

- ZIP inventory: `ev_bb1ddfd3c8c9803876b27141971a1df2ab90d591f42eab87f22a64ddf6e0ee66`.
- Mixed data-model assembly identity, framework and references: `ev_3403e615cad18e7d11078d2841db70d5009d97ff3b9bc5b108514c3bbf8ed824`.
- Managed starter identity: `ev_bad3837b85b47e5b3d17a60d2987124480f67c8642f2d0b77a0ee6ef928eb250`.
- Main executable managed classification (not managed): `ev_b01770d1f880bad52fa147560cbc191b8e49f21e6727deb9ce821dbf008927e1`.
- Starter member inventory: `ev_98b0d47f7dbd360b68a0cde93ce28b22ef4a2d60ae97d3be3b9a4a185199f4aa`; 10 types, 40 methods, 39 file-backed CIL method bodies, one external COM declaration. This examines startup infrastructure, not the core editor.
- Ghidra main-executable overview: `ev_eb53b49a8a83684c7be14685988a736e3889760eb79091d44417ab51860a3094`; 511 analyzed procedures, 244 defined strings, eight analysis segments including synthetic loader data. Counts are provider-derived inventory, not feature coverage.
- Focused native startup search: `ev_9586746f6fb4f38ed187d5b5cf98bdab8afe57e2d6251103165adff3f42ebd7c`; identifies the PE entry and MFC/BCG application-framework imports and thunks.
- Entry decompilation at `0x140004000`: `ev_e454042f4df40ef14afac5c13ba450a0b98c8ab1781e0a9fa75471787c83fcaa`; Ghidra pseudocode shows security-cookie initialization and transfer to another startup function. This is limited startup evidence, not recovery of schematic algorithms.

Complete REA bundles, selected vendor artifacts and local investigation intermediates are excluded from the public source tree. The IDs below describe the original local investigation and are not public download links. No claim is made that the supplied software's source has been recovered.

## Tool update and execution environment

The installed `reverse-engineer-anything` skill was updated from v24 to v45 using the [official REA GitHub repository](https://github.com/morluto/rea), pinned to [commit b58aa63796fe6465d241db9cb3c72c918c02890c](https://github.com/morluto/rea/commit/b58aa63796fe6465d241db9cb3c72c918c02890c). The previous skill was backed up locally.

The connected REA server exposes older schemas; only its advertised operations were called. The globally installed CLI is v4.0.1. Native analysis used the downloaded CLI v6.7.0 with existing Node 24, Ghidra 12.1.4, and Java 21 selected for that process. No MCP registration or global runtime configuration was changed. Sevenzip 26.03 was installed to inspect MSI/CAB contents without running the installer.

## Remaining reconstruction work

1. Validate the original electrical editing workflows against a legitimately running Windows reference and representative user-owned projects.
2. Expand symbol types, device functions, wire junction semantics, cross-page references, numbering and schematic rules using explicit test cases.
3. Investigate storage/interchange separately. Start with a documented neutral exchange format or user-owned exports; establish round-trip fixtures before asserting compatibility.
4. Compare the new app with the reference on selected workflows, recording expected results and deviations. Do not use successful startup or model tests as evidence of EPLAN parity.
5. Collect feedback on the MIT-licensed v0.1.0-alpha and prioritize a small number of concrete workflows before expanding scope.

## Added community MCP integration

At the user's request, the [Canary-ECAD EPLAN MCP server](https://github.com/Canary-ECAD/eplan-mcp) was inspected and pinned at commit `0681c75cb5c2d75cbb6ca0db5e83625fdb1c6f4d`. Its MIT-licensed server source is included under `Integrations/third_party`, with its original license. This is community automation source, separate from the proprietary installer evidence above.

The upstream discovery interface works locally, while its live commands need Windows EPLAN. The source explicitly requires server-side DLLs and local script/result files on the EPLAN machine. Its HTTP transport can support future comparison against a Windows reference. No live Windows connection has been tested here.

CircuitDraft gained an independent native automation bridge and companion MCP tools. The app's existing model supports the eight exposed native operations; upstream EPLAN tools are searchable for planning but are not relabeled as working Mac features. See [integration details](../Integrations/README.md) and [verification](../TEST-RESULTS.md).
