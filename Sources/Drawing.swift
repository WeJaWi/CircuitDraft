import AppKit
import SwiftUI

enum Primitive {
    case path([CGPoint], Bool)
    case rect(CGRect)
    case ellipse(CGRect)
}
func line(_ values: Double...) -> Primitive { .path(stride(from:0,to:values.count,by:2).map {CGPoint(x:values[$0],y:values[$0+1])},false) }
func primitives(_ kind: SymbolKind) -> [Primitive] {
    switch kind {
    case .resistor: return [line(-50,0,-26,0),.rect(CGRect(x:-26,y:-12,width:52,height:24)),line(26,0,50,0)]
    case .contact: return [line(-50,0,-20,0),line(-20,0,20,-20),line(20,0,50,0),.ellipse(CGRect(x:-23,y:-3,width:6,height:6)),.ellipse(CGRect(x:17,y:-3,width:6,height:6))]
    case .coil: return [line(-50,0,-28,0),.rect(CGRect(x:-28,y:-18,width:56,height:36)),line(28,0,50,0),line(-12,12,12,-12)]
    case .terminal: return [line(-50,0,-10,0),.ellipse(CGRect(x:-10,y:-10,width:20,height:20)),line(10,0,50,0)]
    case .fuse: return [line(-50,0,50,0),.rect(CGRect(x:-25,y:-10,width:50,height:20))]
    case .motor: return [line(-50,0,-26,0),.ellipse(CGRect(x:-26,y:-26,width:52,height:52)),line(26,0,50,0),line(-10,10,-10,-10,0,3,10,-10,10,10)]
    case .ground: return [line(0,-40,0,0),line(-23,0,23,0),line(-15,8,15,8),line(-6,16,6,16)]
    }
}
func transformedPrimitive(_ primitive: Primitive, by component: Component) -> Primitive {
    switch primitive {
    case .path(let points, let closed): return .path(points.map(component.point), closed)
    case .rect(let r): return .path([CGPoint(x:r.minX,y:r.minY),CGPoint(x:r.maxX,y:r.minY),CGPoint(x:r.maxX,y:r.maxY),CGPoint(x:r.minX,y:r.maxY)].map(component.point),true)
    case .ellipse(let r):
        let center=component.point(CGPoint(x:r.midX,y:r.midY)); let swap=component.rotation % 180 != 0
        let w=swap ? r.height:r.width, h=swap ? r.width:r.height
        return .ellipse(CGRect(x:center.x-w/2,y:center.y-h/2,width:w,height:h))
    }
}
func bezier(_ primitive: Primitive) -> NSBezierPath {
    switch primitive {
    case .path(let points,let closed): let p = NSBezierPath(); if let first = points.first { p.move(to:first) }; for point in points.dropFirst() {p.line(to:point)}; if closed {p.close()}; return p
    case .rect(let rect): return NSBezierPath(rect:rect)
    case .ellipse(let rect): return NSBezierPath(ovalIn:rect)
    }
}
func xml(_ s: String) -> String { s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;") }
func num(_ d: Double) -> String { String(format:"%.2f",locale:Locale(identifier:"en_US_POSIX"),d) }
func svgPage(_ page:SchematicPage,projectName:String) -> String {
    var parts = ["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1400\" height=\"900\" viewBox=\"0 0 1400 900\"><rect width=\"1400\" height=\"900\" fill=\"white\"/>", "<rect x=\"40\" y=\"40\" width=\"1320\" height=\"820\" fill=\"none\" stroke=\"#c7cdd5\"/>","<g fill=\"none\" stroke=\"#176b68\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">"]
    for w in page.wires { let points = w.points(in:page); parts.append("<polyline points=\"\(points.map { "\(num($0.x)),\(num($0.y))" }.joined(separator:" "))\"/>") }
    parts.append("</g>")
    for c in page.components {
        parts.append("<g transform=\"translate(\(num(c.x)) \(num(c.y))) rotate(\(c.rotation))\" fill=\"white\" stroke=\"#243044\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">")
        for primitive in primitives(c.kind) {
            switch primitive {
            case .path(let pts, let close): parts.append("<path fill=\"none\" d=\"M \(pts.map { "\(num($0.x)) \(num($0.y))" }.joined(separator:" L "))\(close ? " Z" : "")\"/>")
            case .rect(let r): parts.append("<rect x=\"\(num(r.minX))\" y=\"\(num(r.minY))\" width=\"\(num(r.width))\" height=\"\(num(r.height))\" fill=\"none\"/>")
            case .ellipse(let r): parts.append("<ellipse cx=\"\(num(r.midX))\" cy=\"\(num(r.midY))\" rx=\"\(num(r.width/2))\" ry=\"\(num(r.height/2))\"/>")
            }
        }
        parts.append("</g><text x=\"\(num(c.x))\" y=\"\(num(c.y-42))\" text-anchor=\"middle\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"14\" font-weight=\"600\" fill=\"#243044\">\(xml(c.tag))</text>")
        if !c.description.isEmpty { parts.append("<text x=\"\(num(c.x))\" y=\"\(num(c.y+48))\" text-anchor=\"middle\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"10\" fill=\"#667085\">\(xml(c.description))</text>") }
    }
    for w in page.wires where !w.label.isEmpty { let p = w.start.resolved(in:page); parts.append("<text x=\"\(num(p.x+8))\" y=\"\(num(p.y-8))\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"11\" fill=\"#176b68\">\(xml(w.label))</text>") }
    parts.append("<text x=\"60\" y=\"825\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"20\" fill=\"#243044\">\(xml(projectName))</text><text x=\"60\" y=\"847\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"12\" fill=\"#667085\">\(xml(page.name)) · CircuitDraft</text></svg>")
    return parts.joined(separator:"\n")
}

@MainActor final class SchematicCanvas: NSView {
    var store: EditorStore!
    var exporting = false
    var hover = CGPoint.zero
    var dragOrigin: CGPoint?
    var dragComponentOrigin: CGPoint?
    var dragSnapshot: Project?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect:bounds,options:[.activeInKeyWindow,.mouseMoved,.inVisibleRect],owner:self))
    }
    func stroke(_ primitive:Primitive, color:NSColor, width:CGFloat = 2) { color.setStroke(); let p = bezier(primitive); p.lineWidth = width; p.lineJoinStyle = .round; p.lineCapStyle = .round; p.stroke() }
    func label(_ text:String, at point:CGPoint, size:CGFloat=12, color:NSColor = .labelColor, centered:Bool=false, bold:Bool=false) {
        let attr:[NSAttributedString.Key:Any] = [.font:bold ? NSFont.systemFont(ofSize:size,weight:.semibold) : NSFont.systemFont(ofSize:size),.foregroundColor:color]
        let s = NSAttributedString(string:text,attributes:attr); let w = s.size().width
        s.draw(at:CGPoint(x:point.x-(centered ? w/2 : 0),y:point.y))
    }
    override func draw(_ dirtyRect:NSRect) {
        guard let store else {return}
        NSColor.white.setFill(); bounds.fill()
        let ink = NSColor(calibratedRed:0.14,green:0.19,blue:0.27,alpha:1), teal = NSColor(calibratedRed:0.09,green:0.42,blue:0.41,alpha:1)
        if store.grid && !exporting {
            NSColor(calibratedWhite:0.84,alpha:1).setFill()
            for x in stride(from:60.0,through:1340.0,by:20) { for y in stride(from:60.0,through:780.0,by:20) { NSBezierPath(ovalIn:NSRect(x:x-0.65,y:y-0.65,width:1.3,height:1.3)).fill() } }
        }
        stroke(.rect(CGRect(x:40,y:40,width:1320,height:820)),color:NSColor(calibratedWhite:0.82,alpha:1),width:1)
        stroke(line(40,800,1360,800),color:NSColor(calibratedWhite:0.82,alpha:1),width:1)
        label(store.project.name,at:CGPoint(x:60,y:815),size:20,color:ink,bold:true)
        label("\(store.page.name)  ·  CircuitDraft",at:CGPoint(x:60,y:843),size:12,color:.gray)
        label("\(store.page.components.count) symbols  /  \(store.page.wires.count) wires",at:CGPoint(x:1110,y:838),size:11,color:.gray)
        for wire in store.page.wires {
            let selected = wire.id == store.selectedWireID && !exporting
            stroke(.path(wire.points(in:store.page),false),color:selected ? .systemBlue : teal,width:selected ? 3 : 2)
            if !wire.label.isEmpty { let a = wire.start.resolved(in:store.page); label(wire.label,at:CGPoint(x:a.x+8,y:a.y-22),size:11,color:teal) }
            // Filled nodes distinguish electrical endpoints from incidental crossings.
            for end in [wire.start,wire.end] { let p=end.resolved(in:store.page); teal.setFill(); NSBezierPath(ovalIn:NSRect(x:p.x-2.5,y:p.y-2.5,width:5,height:5)).fill() }
        }
        for c in store.page.components {
            if c.id == store.selectedID && !exporting {
                NSColor.systemBlue.withAlphaComponent(0.07).setFill(); NSBezierPath(roundedRect:NSRect(x:c.x-64,y:c.y-55,width:128,height:112),xRadius:7,yRadius:7).fill()
                let path=NSBezierPath(roundedRect:NSRect(x:c.x-64,y:c.y-55,width:128,height:112),xRadius:7,yRadius:7); NSColor.systemBlue.withAlphaComponent(0.6).setStroke(); path.lineWidth=1; path.setLineDash([4,3],count:2,phase:0); path.stroke()
            }
            for local in primitives(c.kind) {
                let primitive=transformedPrimitive(local,by:c)
                if case .ellipse(let r) = primitive {NSColor.white.setFill(); NSBezierPath(ovalIn:r).fill()}
                stroke(primitive,color:ink)
            }
            label(c.tag,at:CGPoint(x:c.x,y:c.y-54),size:14,color:ink,centered:true,bold:true)
            if !c.description.isEmpty { label(c.description,at:CGPoint(x:c.x,y:c.y+34),size:10,color:.gray,centered:true) }
            if !exporting {
                for i in c.kind.pins.indices { let p=c.pin(i); NSColor.white.setFill(); NSBezierPath(ovalIn:NSRect(x:p.x-3,y:p.y-3,width:6,height:6)).fill(); stroke(.ellipse(NSRect(x:p.x-3,y:p.y-3,width:6,height:6)),color:teal,width:1.4) }
            }
        }
        if !exporting, let start=store.wireStart {
            let end=store.endpoint(at:hover), wire=Wire(start:start,end:end,verticalFirst:NSEvent.modifierFlags.contains(.option))
            stroke(.path(wire.points(in:store.page),false),color:.systemOrange,width:2)
        }
        if !exporting, case .place(let kind)=store.tool {
            let p=snap(hover); NSGraphicsContext.saveGraphicsState(); let t=NSAffineTransform(); t.translateX(by:p.x,yBy:p.y); t.concat(); for primitive in primitives(kind) {stroke(primitive,color:teal.withAlphaComponent(0.45))}; NSGraphicsContext.restoreGraphicsState()
        }
    }
    func local(_ event:NSEvent) -> CGPoint { convert(event.locationInWindow,from:nil) }
    override func mouseMoved(with event:NSEvent) { hover=local(event); needsDisplay=true }
    override func mouseDown(with event:NSEvent) {
        window?.makeFirstResponder(self); let p=local(event); hover=p
        switch store.tool {
        case .place(let kind): guard p.x>=70,p.x<=1330,p.y>=90,p.y<=740 else {store.status="Place symbols inside the drawing area";return}; store.place(kind,at:p)
        case .wire: guard p.x>=40,p.x<=1360,p.y>=40,p.y<800 else{return}; store.addWire(to:p,verticalFirst:event.modifierFlags.contains(.option))
        case .select:
            store.selectedID=nil; store.selectedWireID=nil
            if let c=store.page.components.reversed().first(where:{abs($0.x-p.x)<58 && abs($0.y-p.y)<48}) {
                store.selectedID=c.id; dragOrigin=p; dragComponentOrigin=CGPoint(x:c.x,y:c.y); dragSnapshot=store.project
            } else {
                for w in store.page.wires.reversed() { let ps=w.points(in:store.page); if zip(ps,ps.dropFirst()).contains(where:{wireDistance(p,$0.0,$0.1)<7}) {store.selectedWireID=w.id;break} }
            }
        }
        needsDisplay=true
    }
    override func mouseDragged(with event:NSEvent) {
        guard let a=dragOrigin,let origin=dragComponentOrigin,let i=store.page.components.firstIndex(where:{$0.id==store.selectedID}) else{return}
        let p=local(event), s=snap(CGPoint(x:origin.x+p.x-a.x,y:origin.y+p.y-a.y))
        store.project.pages[store.pageIndex].components[i].x=max(70,min(1330,s.x)); store.project.pages[store.pageIndex].components[i].y=max(90,min(740,s.y)); needsDisplay=true
    }
    override func mouseUp(with event:NSEvent) {
        if let before=dragSnapshot,before != store.project {store.checkpoint(before)}
        dragOrigin=nil;dragComponentOrigin=nil;dragSnapshot=nil
    }
    override func keyDown(with event:NSEvent) {
        switch event.keyCode {
        case 51,117:store.deleteSelection()
        case 53:store.activate(.select)
        case 123,124,125,126:
            let dx=event.keyCode==123 ? -10.0 : (event.keyCode==124 ? 10.0 : 0)
            let dy=event.keyCode==126 ? -10.0 : (event.keyCode==125 ? 10.0 : 0)
            store.updateComponent {$0.x=max(70,min(1330,$0.x+dx));$0.y=max(90,min(740,$0.y+dy))}
        default:
            switch event.charactersIgnoringModifiers?.lowercased() {case "r":store.rotate();case "w":store.activate(.wire);case "v":store.activate(.select);default:super.keyDown(with:event)}
        }
        needsDisplay=true
    }
}
struct CanvasView:NSViewRepresentable {
    @ObservedObject var store:EditorStore
    @MainActor class Coordinator:NSObject {
        weak var store:EditorStore?
        var fitRequest = -1
        var observation:NSObjectProtocol?
        deinit {if let observation {NotificationCenter.default.removeObserver(observation)}}
    }
    func makeCoordinator()->Coordinator {let c=Coordinator();c.store=store;return c}
    func makeNSView(context:Context)->NSScrollView {
        let scroll=NSScrollView(); scroll.hasVerticalScroller=true;scroll.hasHorizontalScroller=true;scroll.backgroundColor=NSColor(calibratedWhite:0.91,alpha:1)
        let canvas=SchematicCanvas(frame:NSRect(x:0,y:0,width:1400,height:900));canvas.store=store;scroll.documentView=canvas; scroll.allowsMagnification=true; scroll.minMagnification=0.4;scroll.maxMagnification=2
        scroll.magnification=store.zoom
        context.coordinator.observation=NotificationCenter.default.addObserver(forName:NSScrollView.didEndLiveMagnifyNotification,object:scroll,queue:.main) { [weak scroll,weak coordinator=context.coordinator] _ in
            MainActor.assumeIsolated {if let scroll {coordinator?.store?.zoom=scroll.magnification}}
        }
        return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        guard let canvas=scroll.documentView as? SchematicCanvas else{return}
        canvas.store=store;canvas.needsDisplay=true
        if context.coordinator.fitRequest != store.fitRequest {
            context.coordinator.fitRequest=store.fitRequest
            DispatchQueue.main.async {
                let factor=max(0.4,min(2,min(scroll.contentSize.width/1400,scroll.contentSize.height/900)))
                scroll.setMagnification(factor,centeredAt:CGPoint(x:700,y:450));store.zoom=factor
            }
        } else if abs(scroll.magnification-store.zoom)>0.01 {
            scroll.setMagnification(store.zoom,centeredAt:CGPoint(x:700,y:450))
        }
    }
}
