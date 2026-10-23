import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum EditorTool: Equatable { case select, wire, place(SymbolKind) }
@MainActor final class EditorStore: ObservableObject {
    @Published var project = Project.example() { didSet { automation?.documentDidChange() } }
    @Published var pageID: UUID? { didSet { automation?.currentPageDidChange() } }
    @Published var selectedID: UUID?
    @Published var selectedWireID: UUID?
    @Published var tool = EditorTool.select
    @Published var wireStart: Endpoint?
    @Published var status = "Ready · Select a symbol to edit its properties"
    @Published var dirty = false
    @Published var fileURL: URL?
    @Published var zoom: Double = 0.65
    @Published var fitRequest = 0
    @Published var showParts = false
    @Published var grid = true
    @Published var undoStack: [Project] = []
    @Published var redoStack: [Project] = []
    @Published var automationReady = false
    @Published var automationMessage = "Local automation is starting"
    var automation: AutomationBridge?
    func startAutomation() {
        guard automation == nil else { return }
        do {
            automation = try AutomationBridge(store: self)
            automationReady = true
            automationMessage = "Local automation · " + (automation?.directory.path ?? "")
        } catch { automationReady = false; automationMessage = "Automation unavailable: " + error.localizedDescription }
    }
    var pageIndex: Int { project.pages.firstIndex(where: { $0.id == pageID }) ?? 0 }
    var page: SchematicPage { project.pages[pageIndex] }
    var selection: Component? { page.components.first(where: { $0.id == selectedID }) }
    var wireSelection: Wire? { page.wires.first(where: { $0.id == selectedWireID }) }
    init() { pageID = project.pages[0].id }
    func checkpoint(_ before: Project? = nil) {
        undoStack.append(before ?? project)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        dirty = true
    }
    func undo() { guard let p = undoStack.popLast() else { return }; redoStack.append(project); project = p; reconcile(); dirty = true }
    func redo() { guard let p = redoStack.popLast() else { return }; undoStack.append(project); project = p; reconcile(); dirty = true }
    func reconcile() {
        if !project.pages.contains(where: {$0.id == pageID}) { pageID = project.pages[0].id }
        selectedID = nil; selectedWireID = nil; wireStart = nil
    }
    func activate(_ tool: EditorTool) { self.tool = tool; wireStart = nil; status = toolHint }
    var toolHint: String {
        switch tool { case .select: "Select · Drag symbols to move · R rotate · Delete remove"; case .wire: "Wire · Click a pin or grid point, then its destination · Option switches bend · Esc cancels"; case .place(let k): "Place \(k.title.lowercased()) · Click the page · Esc returns to Select" }
    }
    func selectPage(_ id: UUID) { pageID = id; selectedID = nil; selectedWireID = nil; wireStart = nil }
    func addPage() {
        checkpoint(); let p = SchematicPage(name: "\(project.pages.count+1) · New page"); project.pages.append(p); selectPage(p.id)
    }
    func renamePage() {
        let alert = NSAlert(); alert.messageText = "Rename page"; alert.addButton(withTitle: "Rename"); alert.addButton(withTitle: "Cancel")
        let input = NSTextField(string: page.name); input.frame = NSRect(x:0,y:0,width:300,height:24); alert.accessoryView = input
        guard alert.runModal() == .alertFirstButtonReturn, !input.stringValue.trimmingCharacters(in:.whitespaces).isEmpty else { return }
        checkpoint(); project.pages[pageIndex].name = input.stringValue
    }
    func deletePage() {
        guard project.pages.count > 1 else { status = "Keep at least one page in the project"; return }
        let alert = NSAlert(); alert.messageText = "Delete \(page.name)?"; alert.informativeText = "Its symbols and wires will be removed. You can undo this action."; alert.addButton(withTitle:"Delete page"); alert.addButton(withTitle:"Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        checkpoint(); project.pages.remove(at:pageIndex); reconcile()
    }
    func place(_ kind: SymbolKind, at point: CGPoint) {
        checkpoint(); let p = snap(point)
        let existing = Set(project.pages.flatMap(\.components).map(\.tag))
        var n = 1; while existing.contains("\(kind.prefix)\(n)") { n += 1 }
        let c = Component(kind:kind,x:p.x,y:p.y,tag:"\(kind.prefix)\(n)")
        project.pages[pageIndex].components.append(c); selectedID = c.id; selectedWireID = nil
    }
    func updateComponent(_ transform: (inout Component) -> Void) {
        guard let i = page.components.firstIndex(where: {$0.id == selectedID}) else { return }
        checkpoint(); transform(&project.pages[pageIndex].components[i])
    }
    func updateWire(_ transform: (inout Wire) -> Void) {
        guard let i = page.wires.firstIndex(where: {$0.id == selectedWireID}) else { return }
        checkpoint(); transform(&project.pages[pageIndex].wires[i])
    }
    func rotate() { updateComponent { $0.rotation = ($0.rotation+90)%360 } }
    func deleteSelection() {
        guard selectedID != nil || selectedWireID != nil else { return }
        checkpoint()
        if let id = selectedID {
            project.pages[pageIndex].wires.removeAll(where: {$0.start.componentID == id || $0.end.componentID == id})
            project.pages[pageIndex].components.removeAll(where: {$0.id == id})
        }
        if let id = selectedWireID { project.pages[pageIndex].wires.removeAll(where: {$0.id == id}) }
        selectedID = nil; selectedWireID = nil
    }
    func endpoint(at p: CGPoint) -> Endpoint {
        for c in page.components.reversed() { for i in c.kind.pins.indices { let pp = c.pin(i); if distance(pp,p) < 14 { return Endpoint(x:pp.x,y:pp.y,componentID:c.id,pin:i) } } }
        let s = snap(p); return Endpoint(x:s.x,y:s.y)
    }
    func addWire(to point: CGPoint, verticalFirst: Bool) {
        let end = endpoint(at:point)
        guard let start = wireStart else { wireStart = end; status = "Wire started · Click the destination pin or grid point"; return }
        guard distance(start.resolved(in:page),end.resolved(in:page)) > 1 else { return }
        checkpoint(); project.pages[pageIndex].wires.append(Wire(start:start,end:end,verticalFirst:verticalFirst)); wireStart = nil; status = toolHint
    }
    func confirmDiscard() -> Bool {
        guard dirty else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes before continuing?"; alert.informativeText = "Your project contains unsaved changes."; alert.addButton(withTitle:"Save"); alert.addButton(withTitle:"Discard"); alert.addButton(withTitle:"Cancel")
        switch alert.runModal() { case .alertFirstButtonReturn: return save(); case .alertSecondButtonReturn: return true; default: return false }
    }
    func newProject() { guard confirmDiscard() else { return }; project = Project(); fileURL = nil; dirty = false; undoStack = []; redoStack = []; reconcile(); status = "New project · Choose a symbol to begin" }
    func open() {
        guard confirmDiscard() else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.message = "Open a CircuitDraft JSON project"; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { project = try JSONDecoder().decode(Project.self,from:Data(contentsOf:url)).validated(); fileURL = url; dirty = false; undoStack = []; redoStack = []; reconcile(); status = "Opened \(url.lastPathComponent)" } catch { report(error) }
    }
    @discardableResult func save(as saveAs: Bool = false) -> Bool {
        var url = fileURL
        if saveAs || url == nil {
            let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "\(project.name).circuitdraft.json"; panel.message = "Save your editable CircuitDraft project"
            guard panel.runModal() == .OK else { return false }; url = panel.url
        }
        guard let url else { return false }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; try encoder.encode(project).write(to:url,options:.atomic); fileURL = url; dirty = false; status = "Saved \(url.lastPathComponent)"; return true } catch { report(error); return false }
    }
    func exportCSV() { exportText(partsCSV(project), name:"\(project.name)-parts.csv", type:.commaSeparatedText) }
    func exportSVG() { exportText(svgPage(page,projectName:project.name), name:"\(page.name).svg",type:.svg) }
    func exportText(_ text: String, name: String, type: UTType) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [type]; panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try text.write(to:url,atomically:true,encoding:.utf8); status = "Exported \(url.lastPathComponent)" } catch { report(error) }
    }
    func exportPDF() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = "\(page.name).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let canvas = SchematicCanvas(frame:NSRect(x:0,y:0,width:1400,height:900)); canvas.store = self; canvas.exporting = true
        do { try canvas.dataWithPDF(inside:canvas.bounds).write(to:url,options:.atomic); status = "Exported \(url.lastPathComponent)" } catch { report(error) }
    }
    func report(_ error: Error) { let alert = NSAlert(error:error); alert.runModal() }
}
