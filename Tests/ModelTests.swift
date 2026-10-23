import Foundation
import AppKit

@main struct ModelTests {
    @MainActor static func main() throws {
        var assertions = 0
        func check(_ value: @autoclosure () -> Bool, _ message:String) {
            assertions += 1
            guard value() else {fatalError("FAIL: \(message)")}
        }
        var project=Project.example()
        let encoded=try JSONEncoder().encode(project)
        let decoded=try JSONDecoder().decode(Project.self,from:encoded).validated()
        check(decoded == project,"JSON project round trip preserves all data")
        let wire=project.pages[0].wires[0]
        let id=project.pages[0].components[0].id
        project.pages[0].components[0].x += 100
        project.pages[0].components[0].y += 50
        check(wire.start.resolved(in:project.pages[0]) == CGPoint(x:310,y:290),"wire remains attached after symbol move")
        project.pages[0].components[0].rotation=90
        let moved=wire.start.resolved(in:project.pages[0])
        check(abs(moved.x-260)<0.001 && abs(moved.y-340)<0.001,"wire follows rotated pin")
        let transformComponent=Component(kind:.resistor,x:300,y:200,rotation:90,tag:"R1")
        if case .path(let points,_) = transformedPrimitive(line(-50,0,50,0),by:transformComponent) {
            check(points[0] == transformComponent.pin(0),"render transform matches first model pin")
            check(points[1] == transformComponent.pin(1),"render transform matches second model pin")
            check(abs(points[0].x-300)<0.001 && abs(points[0].y-150)<0.001,"rotation preserves symbol center")
        } else {fatalError("Missing primitive path")}
        var invalid=project;invalid.pages=[]
        do {_ = try invalid.validated();fatalError("Expected empty-page rejection")}catch{check(true,"empty project rejected")}
        invalid=project;invalid.pages[0].wires[0].start.pin=99
        do {_ = try invalid.validated();fatalError("Expected invalid-pin rejection")}catch{check(true,"invalid pin rejected")}
        invalid=project;invalid.formatVersion=99
        do {_ = try invalid.validated();fatalError("Expected version rejection")}catch{check(true,"unknown format rejected")}
        invalid=project;invalid.pages[0].components[0].rotation=13
        do {_ = try invalid.validated();fatalError("Expected rotation rejection")}catch{check(true,"unsupported rotation rejected")}
        let parts=partsList(Project.example())
        check(parts.first(where:{$0.part == "TERM-2.5" && $0.description == "Supply terminal"})?.quantity == 1,"different descriptions keep parts separate")
        var bom=Project.example();var second=bom.pages[0].components[0];second.id=UUID();second.tag="X3";bom.pages[1].components.append(second)
        check(partsList(bom).first(where:{$0.description == "Supply terminal"})?.quantity == 2,"parts aggregate over pages")
        bom.pages[0].components[0].description="A, \"quoted\"\nvalue"
        check(partsCSV(bom).contains("\"A, \"\"quoted\"\"\nvalue\""),"CSV quotes comma, quote and newline")
        check(partsCSV(bom).contains("\r\n"),"CSV uses interoperable CRLF rows")
        let svg=svgPage(bom.pages[0],projectName:"A & <B>")
        check(svg.contains("A &amp; &lt;B&gt;"),"SVG escapes text")
        check(svg.contains("&quot;quoted&quot;"),"SVG escapes attribute-sensitive quotes")
        let xmlDoc=try XMLDocument(data:Data(svg.utf8))
        check(xmlDoc.rootElement()?.name == "svg","SVG is parseable XML")
        let store=EditorStore();let original=store.project
        store.place(.motor,at:CGPoint(x:420,y:420));check(store.page.components.count==6,"placement adds symbol")
        store.undo();check(store.project==original,"undo restores document")
        store.redo();check(store.page.components.count==6,"redo restores placement")
        store.selectedID=id // This belongs to a different project and must be harmless.
        store.deleteSelection();check(store.page.components.count==6,"stale selection does not remove another symbol")
        store.selectedID=store.page.components[0].id;store.deleteSelection()
        check(store.page.components.count==5 && store.page.wires.count==3,"deleting symbol removes its attached wires")
        let canvas=SchematicCanvas(frame:NSRect(x:0,y:0,width:1400,height:900));canvas.store=store;canvas.exporting=true
        let pdf=canvas.dataWithPDF(inside:canvas.bounds)
        check(pdf.count>1000 && String(decoding:pdf.prefix(4),as:UTF8.self)=="%PDF","native PDF export produces a real PDF")
        let exampleURL=URL(fileURLWithPath:CommandLine.arguments.count>1 ? CommandLine.arguments[1]:"/tmp/CircuitDraft-example.json")
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(Project.example()).write(to:exampleURL,options:.atomic)
        print("PASS: \(assertions) checks (persistence, validation, pin geometry, rendered rotation, BOM/CSV, SVG, undo/redo, PDF)")
    }
}
