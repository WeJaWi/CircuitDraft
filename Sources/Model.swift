import Foundation
import CoreGraphics

enum SymbolKind: String, Codable, CaseIterable, Identifiable {
    case resistor, contact, coil, terminal, fuse, motor, ground
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var prefix: String { switch self { case .resistor: "R"; case .contact: "S"; case .coil: "K"; case .terminal: "X"; case .fuse: "F"; case .motor: "M"; case .ground: "PE" } }
    var pins: [CGPoint] { self == .ground ? [CGPoint(x: 0, y: -40)] : [CGPoint(x: -50, y: 0), CGPoint(x: 50, y: 0)] }
}
struct Component: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: SymbolKind
    var x: Double
    var y: Double
    var rotation = 0
    var tag: String
    var description = ""
    var part = ""
    var manufacturer = ""
    func point(_ local: CGPoint) -> CGPoint {
        let a = Double(rotation) * .pi / 180
        return CGPoint(x: x + local.x * cos(a) - local.y * sin(a), y: y + local.x * sin(a) + local.y * cos(a))
    }
    func pin(_ index: Int) -> CGPoint { point(kind.pins[max(0, min(index, kind.pins.count - 1))]) }
}
struct Endpoint: Codable, Equatable {
    var x: Double
    var y: Double
    var componentID: UUID? = nil
    var pin: Int? = nil
    func resolved(in page: SchematicPage) -> CGPoint {
        if let id = componentID, let i = pin, let c = page.components.first(where: { $0.id == id }) { return c.pin(i) }
        return CGPoint(x: x, y: y)
    }
}
struct Wire: Codable, Identifiable, Equatable {
    var id = UUID()
    var start: Endpoint
    var end: Endpoint
    var verticalFirst = false
    var label = ""
    func points(in page: SchematicPage) -> [CGPoint] {
        let a = start.resolved(in: page), b = end.resolved(in: page)
        return [a, verticalFirst ? CGPoint(x: a.x, y: b.y) : CGPoint(x: b.x, y: a.y), b]
    }
}
struct SchematicPage: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var components: [Component] = []
    var wires: [Wire] = []
}
struct Project: Codable, Equatable {
    var formatVersion = 1
    var name = "Untitled project"
    var pages = [SchematicPage(name: "1 · Main circuit")]
    static func example() -> Project {
        var p = SchematicPage(name: "1 · Control circuit")
        p.components = [
            Component(kind: .terminal, x: 160, y: 240, tag: "X1", description: "Supply terminal", part: "TERM-2.5", manufacturer: "Example"),
            Component(kind: .fuse, x: 340, y: 240, tag: "F1", description: "Control circuit fuse", part: "FUSE-2A", manufacturer: "Example"),
            Component(kind: .contact, x: 540, y: 240, tag: "S1", description: "Normally open switch", part: "SW-NO", manufacturer: "Example"),
            Component(kind: .coil, x: 760, y: 240, tag: "K1", description: "Relay coil", part: "RELAY-24", manufacturer: "Example"),
            Component(kind: .terminal, x: 960, y: 240, tag: "X2", description: "Return terminal", part: "TERM-2.5", manufacturer: "Example")
        ]
        for i in 0..<4 {
            let a = p.components[i], b = p.components[i+1]
            p.wires.append(Wire(start: Endpoint(x: a.x+50, y: a.y, componentID: a.id, pin: 1), end: Endpoint(x: b.x-50, y: b.y, componentID: b.id, pin: 0)))
        }
        return Project(name: "Control circuit example", pages: [p, SchematicPage(name: "2 · Power circuit")])
    }
    func validated() throws -> Project {
        guard formatVersion == 1 else { throw ValidationError.message("Unsupported project format version \(formatVersion).") }
        guard !pages.isEmpty, pages.count <= 500 else { throw ValidationError.message("A project must contain between 1 and 500 pages.") }
        guard Set(pages.map(\.id)).count == pages.count else { throw ValidationError.message("Duplicate page identifiers.") }
        for p in pages {
            guard p.components.count <= 10000, p.wires.count <= 20000 else { throw ValidationError.message("Page exceeds the supported item limit.") }
            let ids = Set(p.components.map(\.id))
            guard ids.count == p.components.count, Set(p.wires.map(\.id)).count == p.wires.count else { throw ValidationError.message("Duplicate item identifiers.") }
            guard p.components.allSatisfy({ $0.x.isFinite && $0.y.isFinite && abs($0.x) < 100000 && abs($0.y) < 100000 && [0,90,180,270].contains($0.rotation) }) else { throw ValidationError.message("Invalid symbol coordinates or rotation.") }
            for w in p.wires {
                for e in [w.start, w.end] {
                    guard e.x.isFinite && e.y.isFinite else { throw ValidationError.message("Invalid wire coordinates.") }
                    if let id = e.componentID {
                        guard let c = p.components.first(where: { $0.id == id }), let pin = e.pin, c.kind.pins.indices.contains(pin) else { throw ValidationError.message("A wire references a missing symbol or pin.") }
                    }
                }
            }
        }
        return self
    }
}
enum ValidationError: LocalizedError { case message(String); var errorDescription: String? { switch self { case .message(let s): s } } }
struct PartRow: Identifiable {
    var id: String { key }
    var key: String
    var kind: String
    var part: String
    var manufacturer: String
    var description: String
    var tags: [String]
    var quantity: Int { tags.count }
}
func partsList(_ project: Project) -> [PartRow] {
    let all = project.pages.flatMap(\.components)
    let groups = Dictionary(grouping: all) { [$0.kind.rawValue, $0.part, $0.manufacturer, $0.description].joined(separator: "\u{1f}") }
    return groups.map { key, cs in
        let c = cs[0]
        return PartRow(key: key, kind: c.kind.title, part: c.part, manufacturer: c.manufacturer, description: c.description, tags: cs.map(\.tag).sorted())
    }.sorted { ($0.kind, $0.part, $0.description) < ($1.kind, $1.part, $1.description) }
}
func csvEscape(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
func partsCSV(_ project: Project) -> String {
    let header = ["Symbol", "Part", "Manufacturer", "Description", "Quantity", "Device tags"]
    let rows = partsList(project).map { [$0.kind, $0.part, $0.manufacturer, $0.description, String($0.quantity), $0.tags.joined(separator: ", ")] }
    return ([header] + rows).map { $0.map(csvEscape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
}
func snap(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x/10).rounded()*10, y: (p.y/10).rounded()*10) }
func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x-b.x, a.y-b.y) }
func wireDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
    let dx = b.x-a.x, dy = b.y-a.y, length = dx*dx+dy*dy
    guard length > 0 else { return distance(p,a) }
    let t = max(0,min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/length))
    return distance(p, CGPoint(x:a.x+t*dx,y:a.y+t*dy))
}
