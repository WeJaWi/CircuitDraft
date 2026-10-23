import SwiftUI
import AppKit

@MainActor final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    weak var store:EditorStore?
    private var windowCloseApproved = false
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.regular);NSApp.activate(ignoringOtherApps:true)
        DispatchQueue.main.async {NSApp.windows.first?.delegate=self}
    }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        if windowCloseApproved {store?.automation?.stop(); return .terminateNow}
        guard store?.confirmDiscard() != false else {return .terminateCancel}
        store?.automation?.stop(); return .terminateNow
    }
    func windowShouldClose(_ sender:NSWindow)->Bool {
        let allowed=store?.confirmDiscard() ?? true
        windowCloseApproved=allowed
        return allowed
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
@main struct CircuitDraftApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store=EditorStore()
    var body:some Scene {
        WindowGroup("CircuitDraft · 0.1 Alpha") {
            EditorView(store:store).frame(minWidth:1100,minHeight:700).onAppear {delegate.store=store;store.startAutomation()}
        }.defaultSize(width:1440,height:920)
        .commands {
            CommandGroup(replacing:.newItem) {Button("New Project",action:store.newProject).keyboardShortcut("n");Button("Open Project…",action:store.open).keyboardShortcut("o")}
            CommandGroup(replacing:.saveItem) {Button("Save",action:{store.save()}).keyboardShortcut("s");Button("Save As…",action:{store.save(as:true)}).keyboardShortcut("s",modifiers:[.command,.shift]);Divider();Button("Export Current Page as PDF…",action:store.exportPDF);Button("Export Current Page as SVG…",action:store.exportSVG);Button("Export Parts List as CSV…",action:store.exportCSV)}
            CommandGroup(replacing:.undoRedo) {Button("Undo",action:store.undo).keyboardShortcut("z").disabled(store.undoStack.isEmpty);Button("Redo",action:store.redo).keyboardShortcut("z",modifiers:[.command,.shift]).disabled(store.redoStack.isEmpty)}
            CommandMenu("Schematic") {Button("Select Tool",action:{store.activate(.select)});Button("Wire Tool",action:{store.activate(.wire)});Button("Rotate Symbol",action:store.rotate).keyboardShortcut("r",modifiers:.command);Button("Delete Selection",action:store.deleteSelection);Divider();Button("Add Page",action:store.addPage);Button("Rename Page…",action:store.renamePage);Button("Parts List",action:{store.showParts=true}).keyboardShortcut("b",modifiers:[.command,.shift])}
        }
    }
}
struct EditorView:View {
    @ObservedObject var store:EditorStore
    var body:some View {
        VStack(spacing:0) {
            header
            Divider()
            HSplitView {
                sidebar.frame(minWidth:190,idealWidth:210,maxWidth:260)
                VStack(spacing:0) {
                    toolbar
                    Divider()
                    CanvasView(store:store).frame(minWidth:600,minHeight:400)
                }
                inspector.frame(minWidth:230,idealWidth:250,maxWidth:320)
            }
            Divider()
            HStack(spacing:10) { Circle().fill(store.dirty ? Color.orange : Color.teal).frame(width:6,height:6);Text(store.status).lineLimit(1);Spacer();Text("10 unit grid · \(store.page.components.count) symbols · \(store.page.wires.count) wires").foregroundStyle(.secondary) }.font(.system(size:11)).padding(.horizontal,16).frame(height:30).background(Color(nsColor:.windowBackgroundColor))
        }.background(Color(nsColor:.windowBackgroundColor)).preferredColorScheme(.light)
        .sheet(isPresented:$store.showParts) {PartsView(store:store)}
    }
    var header:some View {
        HStack(spacing:14) {
            Image(systemName:"point.3.connected.trianglepath.dotted").font(.system(size:26,weight:.semibold)).foregroundStyle(.teal)
            VStack(alignment:.leading,spacing:3) {Text("CircuitDraft").font(.system(size:17,weight:.bold));Text("0.1 ALPHA · ELECTRICAL SCHEMATICS").font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(1.5).foregroundStyle(.secondary)}
            Divider().frame(height:32)
            VStack(alignment:.leading,spacing:2) {
                TextField("Project title",text:Binding(get:{store.project.name},set:{v in store.checkpoint();store.project.name=v})).font(.system(size:15,weight:.medium)).textFieldStyle(.plain).frame(maxWidth:360,alignment:.leading)
                Text(store.fileURL?.lastPathComponent ?? "Local project · Save to keep your work").font(.system(size:11)).foregroundStyle(.secondary)
            }
            Spacer()
            Label(store.automationReady ? "MCP ready" : "MCP offline",systemImage:store.automationReady ? "link.circle.fill" : "link.circle").font(.system(size:10,weight:.medium)).foregroundStyle(store.automationReady ? .teal : .secondary).help(store.automationMessage)
            if store.dirty {Text("Edited").font(.system(size:11)).foregroundStyle(.orange)}
            Button(action:store.open) {Label("Open",systemImage:"folder")}
            Button(action:{store.save()}) {Label("Save",systemImage:"square.and.arrow.down")}
            Menu {Button("PDF · Current page",action:store.exportPDF);Button("SVG · Current page",action:store.exportSVG);Button("CSV · Project parts",action:store.exportCSV)} label:{Label("Export",systemImage:"square.and.arrow.up")}.menuStyle(.borderlessButton).fixedSize()
        }.padding(.horizontal,20).frame(height:76)
    }
    var sidebar:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack {Text("PROJECT PAGES").font(.system(size:10,weight:.bold)).tracking(1).foregroundStyle(.secondary);Spacer();Button(action:store.addPage){Image(systemName:"plus")}.buttonStyle(.plain).help("Add page")}.padding(16)
            ScrollView {
                VStack(spacing:5) {ForEach(store.project.pages) {p in
                    Button(action:{store.selectPage(p.id)}) {
                        HStack(alignment:.top,spacing:9) {Image(systemName:"doc.text").foregroundStyle(p.id==store.pageID ? .teal : .gray);VStack(alignment:.leading,spacing:5){Text(p.name).font(.system(size:12,weight:.medium)).lineLimit(2);Text("\(p.components.count) symbols").font(.system(size:10)).foregroundStyle(.secondary)};Spacer()}.padding(11).frame(maxWidth:.infinity).background(p.id==store.pageID ? Color.teal.opacity(0.10):.clear).clipShape(RoundedRectangle(cornerRadius:7))
                    }.buttonStyle(.plain).contextMenu {Button("Rename…") {store.selectPage(p.id);store.renamePage()};Button("Delete page") {store.selectPage(p.id);store.deletePage()}.disabled(store.project.pages.count==1)}
                }}.padding(.horizontal,9)
            }.frame(minHeight:100,maxHeight:220)
            HStack {Button("Rename",action:store.renamePage);Spacer();Button(action:store.deletePage){Image(systemName:"trash")}.disabled(store.project.pages.count==1)}.font(.system(size:11)).buttonStyle(.borderless).padding(.horizontal,16).padding(.bottom,16)
            Divider()
            Text("SYMBOL LIBRARY").font(.system(size:10,weight:.bold)).tracking(1).foregroundStyle(.secondary).padding(16)
            VStack(spacing:4) {ForEach(SymbolKind.allCases) {kind in
                Button(action:{store.activate(.place(kind))}) {
                    HStack(spacing:12) {SymbolIcon(kind:kind).frame(width:42,height:30);Text(kind.title).font(.system(size:12));Spacer();Image(systemName:"plus").font(.system(size:9)).foregroundStyle(.tertiary)}.padding(.horizontal,12).padding(.vertical,5).background(store.tool == .place(kind) ? Color.teal.opacity(0.12):.clear).clipShape(RoundedRectangle(cornerRadius:6))
                }.buttonStyle(.plain)
            }}.padding(.horizontal,9)
            Spacer(minLength:12)
            Button(action:{store.showParts=true}) {Label("Project parts list",systemImage:"list.bullet.rectangle")}.buttonStyle(.bordered).frame(maxWidth:.infinity).padding(14)
            Text("Original schematic workspace\nJSON · PDF · SVG · CSV\nLocal MCP automation available").font(.system(size:10)).foregroundStyle(.secondary).lineSpacing(3).padding(.horizontal,16).padding(.bottom,16)
        }
    }
    var toolbar:some View {
        HStack(spacing:8) {
            toolButton("Select",icon:"cursorarrow",active:store.tool == .select){store.activate(.select)}
            toolButton("Wire",icon:"point.topleft.down.to.point.bottomright.curvepath",active:store.tool == .wire){store.activate(.wire)}
            Divider().frame(height:20)
            Button(action:store.rotate){Image(systemName:"rotate.right")}.help("Rotate symbol (R)").disabled(store.selection==nil)
            Button(action:store.deleteSelection){Image(systemName:"trash")}.help("Delete selection").disabled(store.selection==nil && store.wireSelection==nil)
            Divider().frame(height:20)
            Button(action:store.undo){Image(systemName:"arrow.uturn.backward")}.disabled(store.undoStack.isEmpty).help("Undo")
            Button(action:store.redo){Image(systemName:"arrow.uturn.forward")}.disabled(store.redoStack.isEmpty).help("Redo")
            Spacer()
            Toggle(isOn:$store.grid){Image(systemName:"circle.grid.3x3")}.toggleStyle(.button).help("Show grid")
            Button(action:{store.zoom=max(0.4,store.zoom-0.1)}){Image(systemName:"minus.magnifyingglass")}
            Text("\(Int(store.zoom*100))%").font(.system(size:11,design:.monospaced)).frame(width:35)
            Button(action:{store.zoom=min(2,store.zoom+0.1)}){Image(systemName:"plus.magnifyingglass")}
            Button("Fit") {store.fitRequest += 1}.font(.system(size:11))
        }.buttonStyle(.borderless).padding(.horizontal,12).frame(height:44)
    }
    func toolButton(_ title:String,icon:String,active:Bool,action:@escaping()->Void)->some View {Button(action:action){Label(title,systemImage:icon).font(.system(size:12,weight:active ? .semibold:.regular)).padding(.horizontal,9).padding(.vertical,6).background(active ? Color.teal.opacity(0.12):.clear).clipShape(RoundedRectangle(cornerRadius:6))}.foregroundStyle(active ? .teal:.primary)}
    var inspector:some View {
        VStack(alignment:.leading,spacing:0) {
            Text("PROPERTIES").font(.system(size:10,weight:.bold)).tracking(1).foregroundStyle(.secondary).padding(16)
            Divider()
            ScrollView {VStack(alignment:.leading,spacing:17) {
                if let c=store.selection {
                    HStack {SymbolIcon(kind:c.kind).frame(width:55,height:40);VStack(alignment:.leading,spacing:4){Text(c.kind.title).font(.system(size:17,weight:.semibold));Text("\(c.rotation)° rotation").font(.system(size:11)).foregroundStyle(.secondary)}}
                    field("Device tag",value:c.tag){v in store.updateComponent{$0.tag=v}}
                    field("Description",value:c.description){v in store.updateComponent{$0.description=v}}
                    Divider()
                    Text("PART INFORMATION").font(.system(size:10,weight:.bold)).tracking(0.6).foregroundStyle(.secondary)
                    field("Part number",value:c.part){v in store.updateComponent{$0.part=v}}
                    field("Manufacturer",value:c.manufacturer){v in store.updateComponent{$0.manufacturer=v}}
                    Divider()
                    HStack {Text("Position");Spacer();Text("\(Int(c.x)), \(Int(c.y))").monospacedDigit().foregroundStyle(.secondary)}.font(.system(size:11))
                    Button(action:store.rotate){Label("Rotate 90°",systemImage:"rotate.right")}.frame(maxWidth:.infinity)
                    Text("Wires attached to pins follow when you move or rotate this symbol.").font(.system(size:11)).foregroundStyle(.secondary).lineSpacing(4)
                    Button(role:.destructive,action:store.deleteSelection){Label("Delete symbol & attached wires",systemImage:"trash")}.font(.system(size:11))
                } else if let w=store.wireSelection {
                    Label("Wire",systemImage:"point.topleft.down.to.point.bottomright.curvepath").font(.system(size:17,weight:.semibold))
                    field("Wire label",value:w.label){v in store.updateWire{$0.label=v}}
                    Toggle("Vertical segment first",isOn:Binding(get:{store.wireSelection?.verticalFirst ?? false},set:{v in store.updateWire{$0.verticalFirst=v}})).font(.system(size:12))
                    Text("Endpoints connect to pins or fixed grid points. Crossings do not create connections.").font(.system(size:11)).foregroundStyle(.secondary).lineSpacing(4)
                    Button(role:.destructive,action:store.deleteSelection){Label("Delete wire",systemImage:"trash")}
                } else {
                    Image(systemName:"cursorarrow.and.square.on.square.dashed").font(.system(size:30)).foregroundStyle(.teal).padding(.top,14)
                    Text("Build your circuit").font(.system(size:17,weight:.semibold))
                    Text("Choose a symbol from the library, then click the page to place it.").font(.system(size:12)).foregroundStyle(.secondary).lineSpacing(5)
                    Divider()
                    tip("V","Select and move")
                    tip("W","Draw a wire")
                    tip("R","Rotate selection")
                    tip("⌫","Delete selection")
                    tip("Esc","Cancel / select")
                    tip("⌥","Switch wire bend")
                    Text("Use the arrow keys to nudge a selected symbol. Pinch or use the zoom controls to inspect the page.").font(.system(size:11)).foregroundStyle(.secondary).lineSpacing(4)
                }
            }.padding(16)}
            Spacer(minLength:0)
        }
    }
    func field(_ title:String,value:String,set:@escaping(String)->Void)->some View {VStack(alignment:.leading,spacing:6){Text(title).font(.system(size:11)).foregroundStyle(.secondary);TextField(title,text:Binding(get:{value},set:set)).textFieldStyle(.roundedBorder)}}
    func tip(_ key:String,_ title:String)->some View {HStack{Text(title).font(.system(size:11));Spacer();Text(key).font(.system(size:10,design:.monospaced)).padding(.horizontal,6).padding(.vertical,3).background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius:3))}}
}
struct SymbolIcon:View {
    var kind:SymbolKind
    var body:some View {Canvas {context,size in
        let scale=min(size.width/110,size.height/65)
        var ctx=context;ctx.translateBy(x:size.width/2,y:size.height/2);ctx.scaleBy(x:scale,y:scale)
        for primitive in primitives(kind) {
            var p=Path()
            switch primitive {case .path(let points,let close): if let a=points.first {p.move(to:a)};for b in points.dropFirst(){p.addLine(to:b)};if close{p.closeSubpath()};case .rect(let r):p.addRect(r);case .ellipse(let r):p.addEllipse(in:r)}
            ctx.stroke(p,with:.color(.teal),style:StrokeStyle(lineWidth:2.5,lineCap:.round,lineJoin:.round))
        }
    }}
}
struct PartsView:View {
    @ObservedObject var store:EditorStore
    @Environment(\.dismiss) var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {VStack(alignment:.leading,spacing:5){Text("Project parts list").font(.system(size:23,weight:.bold));Text("All \(store.project.pages.count) pages · \(store.project.pages.flatMap(\.components).count) symbols · Grouped by symbol, part, manufacturer and description").font(.system(size:12)).foregroundStyle(.secondary)};Spacer();Button("Done"){dismiss()}.keyboardShortcut(.cancelAction)}
            Table(partsList(store.project)) {
                TableColumn("Symbol",value:\.kind).width(90)
                TableColumn("Part",value:\.part).width(120)
                TableColumn("Manufacturer",value:\.manufacturer).width(120)
                TableColumn("Description",value:\.description)
                TableColumn("Qty") {Text(String($0.quantity))}.width(40)
                TableColumn("Device tags") {Text($0.tags.joined(separator:", "))}.width(130)
            }.frame(minHeight:300)
            HStack {Text("Rows with empty part information remain visible for completion.").font(.system(size:11)).foregroundStyle(.secondary);Spacer();Button(action:store.exportCSV){Label("Export CSV…",systemImage:"square.and.arrow.up")}.buttonStyle(.borderedProminent).tint(.teal)}
        }.padding(24).frame(width:950,height:520)
    }
}
