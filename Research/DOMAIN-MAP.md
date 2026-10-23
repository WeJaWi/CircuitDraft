# Electrical-schematic domain map

Evidence **XML-DOMAIN-001** is the installer-supplied API documentation, read as data. The descriptions below are original paraphrases; exact identifiers serve as evidence locators. This map informs an independent Mac editor.

- Source: `work/reference/selected/EEplan.EplApi.DataModelNetu.xml` (18,225,120 bytes).
- SHA-256: `d6987eeb31bcb140159620b752622662adb7ac1e74bd4617d355d3a1339f4ac8`.
- Assembly declaration: `Eplan.EplApi.DataModel`.
- Inventory: 30,560 member records: 627 type, 2,882 method, 18,345 property and 8,706 field records.

## Bounded inventory

| Type | Direct method/property/field records | All descendant records |
|---|---:|---:|
| Project | 72 | 113 |
| Page | 39 | 39 |
| Placement | 22 | 26 |
| SymbolReference | 25 | 55 |
| Function | 72 | 259 |
| Connection | 48 | 55 |
| Pin | 28 | 73 |
| ArticleReference | 24 | 24 |

Direct counts include M/P/F records whose owner before the final name segment exactly matches the type. Nested types and their descendants are excluded. Descendant counts include all records under the type prefix, excluding the type record itself.

## Documented concepts and representative identifiers

### Project

A project groups pages, drawing resources and parts references. Its documented lifecycle includes open-state checks and closing. Project-wide naming and hierarchy settings exceed the first editor milestone.

Exact evidence identifiers:

- `P:Eplan.EplApi.DataModel.Project.Pages`
- `P:Eplan.EplApi.DataModel.Project.ProjectName`
- `P:Eplan.EplApi.DataModel.Project.ProjectFullName`
- `P:Eplan.EplApi.DataModel.Project.SymbolLibraries`
- `P:Eplan.EplApi.DataModel.Project.LayerTable`
- `P:Eplan.EplApi.DataModel.Project.ArticleReferences`
- `P:Eplan.EplApi.DataModel.Project.IsReadOnly`
- `M:Eplan.EplApi.DataModel.Project.Close`

Concept dependencies: `Page`, `ArticleReference`, `MasterData.SymbolLibrary`, `LayerTable`.

### Page

A page belongs to a project and has a document type, structured name, drawing size and grid. It exposes function and placement collections. Different collection properties have different inclusion and filtering rules, so a replacement should define its own explicit traversal contract.

Exact evidence identifiers:

- `M:Eplan.EplApi.DataModel.Page.Create(Eplan.EplApi.DataModel.Project,Eplan.EplApi.DataModel.DocumentTypeManager.DocumentType,Eplan.EplApi.DataModel.PagePropertyList)`
- `P:Eplan.EplApi.DataModel.Page.Name`
- `P:Eplan.EplApi.DataModel.Page.PageType`
- `P:Eplan.EplApi.DataModel.Page.Size`
- `P:Eplan.EplApi.DataModel.Page.GridSize`
- `P:Eplan.EplApi.DataModel.Page.Functions`
- `P:Eplan.EplApi.DataModel.Page.AllPlacements`
- `P:Eplan.EplApi.DataModel.Page.AllFirstLevelPlacements`

Concept dependencies: `Project`, `DocumentTypeManager.DocumentType`, `PagePropertyList`, `Function`, `Placement`.

### Placement

A placement is the page-positioned drawing concept, with location, grouping and draw order. Bounding-box and scaling operations support selection and layout. This is a useful separation from the electrical meaning of a device.

Exact evidence identifiers:

- `P:Eplan.EplApi.DataModel.Placement.Page`
- `P:Eplan.EplApi.DataModel.Placement.Location`
- `P:Eplan.EplApi.DataModel.Placement.Group`
- `P:Eplan.EplApi.DataModel.Placement.DrawingOrder`
- `P:Eplan.EplApi.DataModel.Placement.IsPlaced`
- `M:Eplan.EplApi.DataModel.Placement.GetBoundingBox`
- `M:Eplan.EplApi.DataModel.Placement.Scale(System.Double,System.Double)`
- `M:Eplan.EplApi.DataModel.Placement.Remove`

Concept dependencies: `Page`, `Group`, `Eplan.EplApi.Base.PointD`.

### SymbolReference

A placed symbol uses a symbol variant and has graphical connection points. Its graphical connectivity can include corners and junction elements. Displayed property positions are handled separately from the underlying property values.

Exact evidence identifiers:

- `M:Eplan.EplApi.DataModel.SymbolReference.Create(Eplan.EplApi.DataModel.Page,Eplan.EplApi.DataModel.MasterData.SymbolVariant)`
- `P:Eplan.EplApi.DataModel.SymbolReference.SymbolVariant`
- `P:Eplan.EplApi.DataModel.SymbolReference.Location`
- `P:Eplan.EplApi.DataModel.SymbolReference.GraphicalConnectionPoints`
- `P:Eplan.EplApi.DataModel.SymbolReference.GraphicalConnections`
- `P:Eplan.EplApi.DataModel.SymbolReference.PropertyPlacements`
- `P:Eplan.EplApi.DataModel.SymbolReference.SymbolWiringType`

Concept dependencies: `Page`, `MasterData.SymbolVariant`, `PinBase`, `Graphics.PropertyPlacement`.

### Function

A function represents a logical device or a device component. Documented creation variants support both unplaced project objects and page placements. It owns logical pins, related connections and parts references. Main and subsidiary functions allow several functions to describe one device.

Exact evidence identifiers:

- `M:Eplan.EplApi.DataModel.Function.Create(Eplan.EplApi.DataModel.Page,Eplan.EplApi.DataModel.MasterData.SymbolVariant)`
- `M:Eplan.EplApi.DataModel.Function.Create(Eplan.EplApi.DataModel.Project,Eplan.EplApi.DataModel.FunctionDefinition)`
- `P:Eplan.EplApi.DataModel.Function.Pins`
- `P:Eplan.EplApi.DataModel.Function.Connections`
- `P:Eplan.EplApi.DataModel.Function.ArticleReferences`
- `P:Eplan.EplApi.DataModel.Function.FunctionDefinition`
- `P:Eplan.EplApi.DataModel.Function.FunctionCategory`
- `P:Eplan.EplApi.DataModel.Function.IsMainFunction`
- `P:Eplan.EplApi.DataModel.Function.SubFunctions`
- `P:Eplan.EplApi.DataModel.Function.ParentFunction`
- `M:Eplan.EplApi.DataModel.Function.RemoveFromPage`

Concept dependencies: `Project`, `Page`, `MasterData.SymbolVariant`, `FunctionDefinition`, `Pin`, `Connection`, `ArticleReference`.

### Connection

A logical connection links two connection points and can exist before page placement. Either endpoint can be absent in the documented accessors. Endpoint indexes are zero-based. Associated graphical elements and partial connections are exposed separately from the logical endpoints.

Exact evidence identifiers:

- `M:Eplan.EplApi.DataModel.Connection.#ctor(Eplan.EplApi.DataModel.Project,Eplan.EplApi.DataModel.PinBase,Eplan.EplApi.DataModel.PinBase)`
- `P:Eplan.EplApi.DataModel.Connection.StartPin`
- `P:Eplan.EplApi.DataModel.Connection.EndPin`
- `P:Eplan.EplApi.DataModel.Connection.StartIndex`
- `P:Eplan.EplApi.DataModel.Connection.EndIndex`
- `P:Eplan.EplApi.DataModel.Connection.StartSymbolReference`
- `P:Eplan.EplApi.DataModel.Connection.EndSymbolReference`
- `P:Eplan.EplApi.DataModel.Connection.SymbolReferences`
- `P:Eplan.EplApi.DataModel.Connection.SubConnections`
- `P:Eplan.EplApi.DataModel.Connection.KindOfWire`
- `P:Eplan.EplApi.DataModel.Connection.ArticleReferences`

Concept dependencies: `Project`, `PinBase`, `Pin`, `SymbolReference`, `Page`, `ArticleReference`.

### Pin

A pin expresses the logical connection point of a function. A mapping can attach it to a graphical symbol terminal; that mapping need not preserve the same index. Definition-level pins may have no owning function or actual connections. Limits, potential and signal classifications are documented pin properties.

Exact evidence identifiers:

- `P:Eplan.EplApi.DataModel.Pin.ParentFunction`
- `P:Eplan.EplApi.DataModel.Pin.Designation`
- `P:Eplan.EplApi.DataModel.Pin.SymbolConnPoint`
- `P:Eplan.EplApi.DataModel.Pin.Connections`
- `P:Eplan.EplApi.DataModel.Pin.TargetPins`
- `P:Eplan.EplApi.DataModel.Pin.MaxConnectionCount`
- `P:Eplan.EplApi.DataModel.Pin.PinPotential`
- `P:Eplan.EplApi.DataModel.Pin.Signal`
- `P:Eplan.EplApi.DataModel.Pin.FunctionDefinition`

Concept dependencies: `Function`, `FunctionDefinition`, `PinBase`, `Connection`.

### ArticleReference

A parts reference attaches a catalog part identity, variant and quantity to a project, function or connection. It is documented as an offline editing object whose changes require an explicit store operation. The reference position can be one-based and is distinct from array position. Some omitted reference values inherit catalog values.

Exact evidence identifiers:

- `P:Eplan.EplApi.DataModel.ArticleReference.PartNr`
- `P:Eplan.EplApi.DataModel.ArticleReference.VariantNr`
- `P:Eplan.EplApi.DataModel.ArticleReference.Count`
- `P:Eplan.EplApi.DataModel.ArticleReference.ParentObject`
- `P:Eplan.EplApi.DataModel.ArticleReference.ReferencePos`
- `P:Eplan.EplApi.DataModel.ArticleReference.Article`
- `P:Eplan.EplApi.DataModel.ArticleReference.Properties`
- `M:Eplan.EplApi.DataModel.ArticleReference.StoreToObject`

Concept dependencies: `Project`, `Function`, `Connection`, `Article`.

The supporting `PinBase` declarations distinguish a terminal index, a parent symbol, direction and a location measured from the symbol insertion point: `P:Eplan.EplApi.DataModel.PinBase.Index`, `P:Eplan.EplApi.DataModel.PinBase.Parent`, `P:Eplan.EplApi.DataModel.PinBase.Direction`, and `P:Eplan.EplApi.DataModel.PinBase.Location`.

## Design implications for CircuitDraft

These are reconstruction choices inferred from the conceptual separation above, not recovered implementation details:

- Keep drawing placement, reusable symbol geometry, device meaning and endpoint connectivity separate.
- Store independent project/page/device/pin/wire/part records with stable replacement-owned IDs.
- Build parts-list quantities from explicit part assignments and define grouping by part number plus variant.
- Use a new documented project format for the first Mac editor; EPLAN project interoperability remains unestablished.

## Evidence limits

- Evidence is static XML API documentation supplied in the installer; no EPLAN application behavior was executed or observed.
- The XML contains generated internal-looking and native-interoperability declarations; record presence does not establish supported public API availability.
- These declarations do not establish native project-file encoding, database schema, binary compatibility, or successful import/export of EPLAN projects.
- Relationships below describe documented concepts and signatures, not an independently verified class inheritance graph.
- Counts describe records in this one XML file, including overloads, generated members and internal-looking entries; they are not feature or runtime coverage counts.
- No vendor source code, symbol graphics, catalog data or examples are incorporated into the proposed replacement. New implementation choices require their own validation.
