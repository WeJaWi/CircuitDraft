import Foundation
import AppKit

/// Local, same-user RPC. Requests and responses are JSON files; there is no listener or network service.
@MainActor final class AutomationBridge {
    static let actions = ["status", "get_project", "add_page", "add_symbol", "connect_pins", "update_symbol", "parts_list", "export_svg"]
    private weak var store: EditorStore?
    let directory: URL
    private let requests: URL
    private let responses: URL
    private var timer: Timer?
    private(set) var revision = 0
    private var responseCache: [String: [String: Any]] = [:]
    private let fileManager = FileManager.default
    private var isProcessing = false
    private var stopped = false

    init(store: EditorStore, directory override: URL? = nil, startTimer: Bool = true) throws {
        self.store = store
        if let override { directory = override }
        else if let path = ProcessInfo.processInfo.environment["CIRCUITDRAFT_AUTOMATION_DIR"], !path.isEmpty {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw RPCError("The user Application Support directory is unavailable.") }
            directory = support.appendingPathComponent("CircuitDraft/Automation", isDirectory: true)
        }
        requests = directory.appendingPathComponent("Requests", isDirectory: true)
        responses = directory.appendingPathComponent("Responses", isDirectory: true)
        for folder in [directory, requests, responses] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        }
        try writeState()
        if startTimer {
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
            if let timer { RunLoop.main.add(timer, forMode: .common) }
        }
    }
    func stop() {
        stopped = true; timer?.invalidate(); timer = nil
        try? writeState(running: false)
    }
    func documentDidChange() { revision += 1; refreshState() }
    func currentPageDidChange() { refreshState() }
    private func refreshState() {
        guard !stopped else { return }
        do { try writeState() }
        catch { store?.automationReady = false; store?.automationMessage = "Automation state could not be written: \(error.localizedDescription)" }
    }
    private func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
    private func write(_ value: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private func writeState(running: Bool = true) throws {
        guard let store else { return }
        try write(["running": running, "pid": ProcessInfo.processInfo.processIdentifier,
                   "revision": revision, "project": try object(store.project),
                   "pageID": store.page.id.uuidString, "protocolVersion": 1,
                   "updatedAt": ISO8601DateFormatter().string(from: Date())],
                  to: directory.appendingPathComponent("State.json"))
    }
    func poll() {
        guard !isProcessing, !stopped else { return }
        isProcessing = true
        defer { isProcessing = false }
        guard let files = try? fileManager.contentsOfDirectory(at: requests, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { return }
        for file in files.filter({ $0.pathExtension == "json" }).sorted(by: {$0.lastPathComponent < $1.lastPathComponent}).prefix(50) {
            let fileID = file.deletingPathExtension().lastPathComponent
            guard UUID(uuidString: fileID) != nil else { continue }
            let responseURL = responses.appendingPathComponent(fileID + ".json")
            if fileManager.fileExists(atPath: responseURL.path) { try? fileManager.removeItem(at: file); continue }
            do {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) <= 1_048_576 else { throw RPCError("Request must be a regular JSON file no larger than 1 MiB.") }
                let parsed = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
                guard let request = parsed as? [String: Any], let id = request["id"] as? String, id.lowercased() == fileID.lowercased() else { throw RPCError("Request id must match its UUID filename.") }
                let response: [String: Any]
                if let cached = responseCache[fileID.lowercased()] { response = cached }
                else {
                    response = handle(request)
                    responseCache[fileID.lowercased()] = response
                    if responseCache.count > 1000 { responseCache.removeValue(forKey: responseCache.keys.first!) }
                }
                try write(response, to: responseURL)
                try fileManager.removeItem(at: file)
            } catch {
                let response: [String: Any] = ["id": fileID, "success": false, "error": error.localizedDescription, "revision": revision]
                if (try? write(response, to: responseURL)) != nil { try? fileManager.removeItem(at: file) }
            }
        }
    }
    /// Kept separate from filesystem polling for deterministic protocol tests.
    func handle(_ request: [String: Any]) -> [String: Any] {
        let id = request["id"] as? String ?? ""
        do {
            guard UUID(uuidString: id) != nil else { throw RPCError("id must be a UUID string.") }
            guard let action = request["action"] as? String else { throw RPCError("action must be a string.") }
            let arguments: [String: Any]
            if let supplied = request["arguments"] { guard let dict = supplied as? [String: Any] else { throw RPCError("arguments must be an object.") }; arguments = dict }
            else { arguments = [:] }
            let mutations = ["add_page", "add_symbol", "connect_pins", "update_symbol"]
            if let expected = request["expectedRevision"] {
                let value = try integer(expected, name: "expectedRevision")
                if mutations.contains(action), value != revision { throw RPCError("Stale expectedRevision: received \(value), current revision is \(revision). Read project state and retry.") }
            }
            let result = try execute(action, arguments)
            return ["id": id, "success": true, "result": result, "revision": revision]
        } catch { return ["id": id, "success": false, "error": error.localizedDescription, "revision": revision] }
    }
    private func execute(_ action: String, _ a: [String: Any]) throws -> [String: Any] {
        guard let store else { throw RPCError("The editor is unavailable.") }
        switch action {
        case "status":
            return ["running": true, "pid": ProcessInfo.processInfo.processIdentifier, "revision": revision,
                    "automation_dir": directory.path, "project_name": store.project.name, "page_count": store.project.pages.count,
                    "page_id": store.page.id.uuidString, "actions": Self.actions, "protocol_version": 1]
        case "get_project": return ["project": try object(store.project), "page_id": store.page.id.uuidString]
        case "parts_list":
            return ["parts": partsList(store.project).map { ["kind": $0.kind, "part": $0.part, "manufacturer": $0.manufacturer, "description": $0.description, "quantity": $0.quantity, "tags": $0.tags] as [String: Any] }, "csv": partsCSV(store.project)]
        case "export_svg":
            let index = try pageIndex(a, store)
            return ["svg": svgPage(store.project.pages[index], projectName: store.project.name), "page_id": store.project.pages[index].id.uuidString]
        case "add_page":
            let name = try text(a, "name", required: true)
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RPCError("name must not be empty.") }
            var candidate = store.project
            let page = SchematicPage(name: name); candidate.pages.append(page)
            try commit(candidate, store)
            return try mutationResult(store, index: candidate.pages.count - 1)
        case "add_symbol":
            let index = try pageIndex(a, store)
            let name = try text(a, "kind", required: true)
            guard let kind = SymbolKind(rawValue: name.lowercased()) else { throw RPCError("Unknown symbol kind. Supported: \(SymbolKind.allCases.map(\.rawValue).joined(separator: ", ")).") }
            let x = try coordinate(a, "x", range: 70...1330), y = try coordinate(a, "y", range: 90...740)
            var candidate = store.project
            var tag = try text(a, "tag")
            if tag.isEmpty {
                let existing = Set(candidate.pages.flatMap(\.components).map(\.tag)); var n = 1
                while existing.contains("\(kind.prefix)\(n)") { n += 1 }; tag = "\(kind.prefix)\(n)"
            }
            let c = Component(kind: kind, x: snap(CGPoint(x:x,y:y)).x, y: snap(CGPoint(x:x,y:y)).y,
                              tag: tag, description: try text(a, "description"), part: try text(a, "part"), manufacturer: try text(a, "manufacturer"))
            candidate.pages[index].components.append(c)
            try commit(candidate, store)
            var result = try mutationResult(store, index: index); result["component_id"] = c.id.uuidString; result["component"] = try object(c); return result
        case "connect_pins":
            let index = try pageIndex(a, store), page = store.project.pages[index]
            let startID = try uuid(a, "start_component_id"), endID = try uuid(a, "end_component_id")
            let startPin = try requiredInteger(a, "start_pin"), endPin = try requiredInteger(a, "end_pin")
            guard let first = page.components.first(where: {$0.id == startID}), let last = page.components.first(where: {$0.id == endID}) else { throw RPCError("Both components must exist on the requested page.") }
            guard first.kind.pins.indices.contains(startPin), last.kind.pins.indices.contains(endPin) else { throw RPCError("Pin index is out of range (pins are zero-based).") }
            guard startID != endID || startPin != endPin else { throw RPCError("A wire must connect two different pins.") }
            let p = first.pin(startPin), q = last.pin(endPin)
            guard distance(p, q) > 0.01 else { throw RPCError("The requested pins occupy the same point.") }
            let wire = Wire(start: Endpoint(x:p.x,y:p.y,componentID:startID,pin:startPin), end: Endpoint(x:q.x,y:q.y,componentID:endID,pin:endPin))
            var candidate = store.project; candidate.pages[index].wires.append(wire)
            try commit(candidate, store)
            var result = try mutationResult(store, index:index); result["wire_id"] = wire.id.uuidString; result["wire"] = try object(wire); return result
        case "update_symbol":
            let index = try pageIndex(a, store), id = try uuid(a, "component_id")
            guard let ci = store.project.pages[index].components.firstIndex(where: {$0.id == id}) else { throw RPCError("component_id was not found on the requested page.") }
            var candidate = store.project, c = candidate.pages[index].components[ci]
            for key in ["tag", "description", "part", "manufacturer"] where a[key] != nil {
                let value = try text(a, key)
                switch key { case "tag": c.tag = value; case "description": c.description = value; case "part": c.part = value; default: c.manufacturer = value }
            }
            if a["x"] != nil { c.x = snap(CGPoint(x:try coordinate(a,"x",range:70...1330),y:0)).x }
            if a["y"] != nil { c.y = snap(CGPoint(x:0,y:try coordinate(a,"y",range:90...740))).y }
            if a["rotation"] != nil {
                let r = try requiredInteger(a, "rotation")
                guard [0,90,180,270].contains(r) else { throw RPCError("rotation must be 0, 90, 180 or 270 degrees.") }; c.rotation = r
            }
            candidate.pages[index].components[ci] = c
            if candidate != store.project { try commit(candidate,store) }
            var result = try mutationResult(store,index:index); result["component_id"] = c.id.uuidString; result["component"] = try object(c); return result
        default: throw RPCError("Unsupported action '\(action)'. Supported: \(Self.actions.joined(separator: ", ")).")
        }
    }
    private func commit(_ candidate: Project, _ store: EditorStore) throws {
        _ = try candidate.validated()
        store.checkpoint(); store.project = candidate
        store.status = "Updated through local automation · Undo is available"
    }
    private func mutationResult(_ store: EditorStore, index: Int) throws -> [String: Any] {
        ["project": try object(store.project), "page": try object(store.project.pages[index]), "page_id": store.project.pages[index].id.uuidString]
    }
    private func pageIndex(_ a: [String: Any], _ store: EditorStore) throws -> Int {
        guard a["page_id"] != nil else { return store.pageIndex }
        let id = try uuid(a, "page_id")
        guard let i = store.project.pages.firstIndex(where: {$0.id == id}) else { throw RPCError("page_id was not found.") }; return i
    }
    private func uuid(_ a: [String: Any], _ key: String) throws -> UUID {
        guard let value = a[key] as? String, let id = UUID(uuidString:value) else { throw RPCError("\(key) must be a UUID string.") }; return id
    }
    private func text(_ a: [String: Any], _ key: String, required: Bool = false) throws -> String {
        guard let supplied = a[key] else { if required { throw RPCError("Missing \(key).") }; return "" }
        guard let value = supplied as? String, value.count <= 10000 else { throw RPCError("\(key) must be a string of at most 10,000 characters.") }; return value
    }
    private func integer(_ value: Any, name: String) throws -> Int {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
              number.doubleValue.rounded() == number.doubleValue, number.doubleValue >= Double(Int.min), number.doubleValue < Double(Int.max) else { throw RPCError("\(name) must be an integer.") }
        return number.intValue
    }
    private func requiredInteger(_ a: [String: Any], _ key: String) throws -> Int {
        guard let value = a[key] else { throw RPCError("Missing \(key).") }; return try integer(value,name:key)
    }
    private func coordinate(_ a: [String: Any], _ key: String, range: ClosedRange<Double>) throws -> Double {
        guard let n = a[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, range.contains(n.doubleValue) else { throw RPCError("\(key) must be a finite number between \(Int(range.lowerBound)) and \(Int(range.upperBound)).") }
        return n.doubleValue
    }
}
struct RPCError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
