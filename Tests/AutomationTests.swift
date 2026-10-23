import Foundation
import AppKit

@main struct AutomationTests {
    @MainActor static func main() throws {
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            count += 1; guard value() else { fatalError("FAIL: \(message)") }
        }
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/automation-test-\(UUID().uuidString)")
        defer {try? FileManager.default.removeItem(at: directory)}
        let store = EditorStore()
        let bridge = try AutomationBridge(store: store, directory: directory, startTimer: false)
        store.automation = bridge
        func request(_ action: String, _ arguments: [String: Any] = [:], revision: Int? = nil) -> [String: Any] {
            var r: [String: Any] = ["id": UUID().uuidString, "action": action, "arguments": arguments]
            if let revision { r["expectedRevision"] = revision }
            return bridge.handle(r)
        }
        func ok(_ response: [String: Any]) -> Bool { response["success"] as? Bool == true }
        func result(_ response: [String: Any]) -> [String: Any] { response["result"] as? [String: Any] ?? [:] }
        check(ok(request("status")), "status action")
        check(ok(request("get_project")), "get_project action")
        let selected = store.page.components[0].id; store.selectedID = selected
        let pageResponse = request("add_page", ["name": "Automation page"], revision: 0)
        check(ok(pageResponse) && bridge.revision == 1, "add page commits one revision")
        let pageID = result(pageResponse)["page_id"] as! String
        check(store.selectedID == selected && store.pageIndex == 0, "automation preserves native selection and page")
        check(store.undoStack.count == 1, "one undo checkpoint per operation")
        let before = store.project
        check(!ok(request("add_page", ["name": "Stale"], revision: 0)), "stale revision rejected")
        check(store.project == before && bridge.revision == 1, "stale mutation is atomic")
        check(!ok(request("add_symbol", ["kind":"resistor", "x":Double.nan, "y":200])), "nonfinite coordinate rejected")
        check(!ok(request("add_symbol", ["kind":"unknown", "x":200, "y":200])), "invalid kind rejected")
        let first = request("add_symbol", ["page_id":pageID, "kind":"resistor", "x":203, "y":207, "tag":"R_TEST", "description":"A & B"], revision:1)
        check(ok(first) && bridge.revision == 2, "add symbol on requested page")
        let firstID = result(first)["component_id"] as! String
        check(store.project.pages[2].components[0].x == 200 && store.project.pages[2].components[0].y == 210, "symbol snaps to grid")
        let second = request("add_symbol", ["page_id":pageID, "kind":"coil", "x":500, "y":210])
        let secondID = result(second)["component_id"] as! String
        check(ok(second), "second symbol")
        check(!ok(request("connect_pins", ["page_id":pageID,"start_component_id":firstID,"start_pin":9,"end_component_id":secondID,"end_pin":0])), "pin range checked")
        let connection = request("connect_pins", ["page_id":pageID,"start_component_id":firstID,"start_pin":1,"end_component_id":secondID,"end_pin":0])
        check(ok(connection) && store.project.pages[2].wires.count == 1, "pin connection action")
        let revBefore = bridge.revision
        let update = request("update_symbol", ["page_id":pageID,"component_id":firstID,"x":300,"rotation":90,"part":"ABC","manufacturer":"Test"])
        check(ok(update) && bridge.revision == revBefore + 1, "multiple property edits use one revision")
        let point = store.project.pages[2].wires[0].start.resolved(in:store.project.pages[2])
        check(abs(point.x-300)<0.001 && abs(point.y-260)<0.001, "RPC movement and rotation preserve pin link")
        let goodProject = store.project
        check(!ok(request("update_symbol", ["page_id":pageID,"component_id":firstID,"tag":"CHANGED","rotation":45])), "invalid rotation rejected")
        check(store.project == goodProject, "failed multi-field update makes no partial edits")
        check(result(request("parts_list"))["parts"] is [[String:Any]], "parts list action")
        let svg = result(request("export_svg", ["page_id":pageID]))["svg"] as! String
        check(svg.contains("A &amp; B"), "SVG export returns escaped project drawing")
        check(!ok(request("unsupported")), "unknown action rejected")
        let uuid = UUID().uuidString
        let path = directory.appendingPathComponent("Requests/\(uuid).json")
        let data = try JSONSerialization.data(withJSONObject:["id":uuid,"action":"add_page","arguments":["name":"File RPC"],"expectedRevision":bridge.revision])
        try data.write(to:path,options:.atomic); bridge.poll()
        let responseURL = directory.appendingPathComponent("Responses/\(uuid).json")
        let response = try JSONSerialization.jsonObject(with:Data(contentsOf:responseURL)) as! [String:Any]
        check(ok(response) && !FileManager.default.fileExists(atPath:path.path), "file RPC creates atomic response and consumes request")
        let afterFile = bridge.revision
        try data.write(to:path,options:.atomic); bridge.poll()
        check(bridge.revision == afterFile, "repeated UUID does not repeat mutation")
        let state = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("State.json"))) as! [String:Any]
        check(state["revision"] as? Int == bridge.revision && state["project"] != nil, "state snapshot matches live revision and document")
        let pageRevision = bridge.revision
        store.selectPage(UUID(uuidString:pageID)!)
        let state2 = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("State.json"))) as! [String:Any]
        check(state2["pageID"] as? String == pageID && bridge.revision == pageRevision, "page selection refreshes snapshot without document revision")
        store.undo()
        check(bridge.revision == pageRevision+1 && store.project.pages.count == 3, "native undo increments bridge revision")
        bridge.stop()
        let stopped = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("State.json"))) as! [String:Any]
        check(stopped["running"] as? Bool == false, "graceful shutdown updates state")
        print("PASS: \(count) automation checks (actions, revisions, validation, atomic edits, pin links, selection, file protocol, deduplication, state, undo, shutdown)")
    }
}
