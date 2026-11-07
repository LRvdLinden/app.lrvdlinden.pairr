import SwiftUI
import SwiftData

/// What the library shows.
enum LibraryFilter: Hashable {
    case all, favorites, recent, withoutCode
    case type(CodeType)
    case home(String)
    case room(String)

    var title: String {
        switch self {
        case .all: String(localized: "All devices")
        case .favorites: String(localized: "Favorites")
        case .recent: String(localized: "Recently added")
        case .withoutCode: String(localized: "Without a code")
        case .type(let t): t.title
        case .home(let h): h
        case .room(let r): r
        }
    }

    func includes(_ d: Device) -> Bool {
        switch self {
        case .all: true
        case .favorites: d.isFavorite
        case .recent: d.createdAt > Date.now.addingTimeInterval(-30 * 24 * 3600)
        case .withoutCode: (d.codes ?? []).isEmpty
        case .type(let t): (d.codes ?? []).contains { $0.type == t }
        case .home(let h): d.home == h
        case .room(let r): d.room == r
        }
    }
}

/// Sheets opened from the main window.
enum ActiveSheet: Identifiable {
    case newDevice(ParsedCode?)
    case homeImport
    case settings

    var id: String {
        switch self {
        case .newDevice(let p): "new-\(p?.id ?? "")"
        case .homeImport: "home"
        case .settings: "settings"
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Device.name) private var devices: [Device]
    @State private var filter: LibraryFilter? = .all
    @State private var selection: UUID?
    @State private var sheet: ActiveSheet?
    @State private var column: NavigationSplitViewColumn = .content
    @State private var path: [UUID] = []
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    var body: some View {
        Group {
            if isCompact {
                // iPhone: straight into the list, devices open in a stack.
                NavigationStack(path: $path) {
                    DeviceListView(filter: filter ?? .all, selection: $selection, sheet: $sheet,
                                   compact: true, filterChoice: $filter)
                        .navigationDestination(for: UUID.self) { id in
                            if let device = devices.first(where: { $0.id == id }) {
                                DeviceDetailView(device: device)
                            }
                        }
                }
            } else {
                splitView
            }
        }
        .sheet(item: $sheet) { sheet in sheetContent(sheet) }
        .onChange(of: appState.pendingAction) { _, action in
            if action == .newDevice { sheet = .newDevice(nil) }
            appState.pendingAction = nil
        }
    }

    private var splitView: some View {
        NavigationSplitView(preferredCompactColumn: $column) {
            SidebarView(devices: devices, filter: $filter, sheet: $sheet)
        } content: {
            DeviceListView(filter: filter ?? .all, selection: $selection, sheet: $sheet)
        } detail: {
            if let id = selection, let device = devices.first(where: { $0.id == id }) {
                DeviceDetailView(device: device) { selection = nil }
                    .id(device.id)
            } else {
                ContentUnavailableView("Choose a device",
                                       systemImage: "square.stack.3d.up",
                                       description: Text("Its codes, details and attachments appear here."))
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
            switch sheet {
            case .newDevice(let parsed):
                DeviceEditorView(device: nil, initialCode: parsed) { created in
                    if isCompact {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { path = [created.id] }
                    } else {
                        selection = created.id
                    }
                }
            case .homeImport:
                #if os(iOS)
                HomeImportView()
                #else
                EmptyView()
                #endif
            case .settings:
                SettingsView(onImportFromHome: {
                    self.sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.sheet = .homeImport }
                })
            }
    }
}

struct SidebarView: View {
    let devices: [Device]
    @Binding var filter: LibraryFilter?
    @Binding var sheet: ActiveSheet?

    private var homes: [String] { Array(Set(devices.map(\.home).filter { !$0.isEmpty })).sorted() }
    private var rooms: [String] { Array(Set(devices.map(\.room).filter { !$0.isEmpty })).sorted() }

    var body: some View {
        List(selection: $filter) {
            Section {
                row(.all, "square.grid.2x2.fill", count: devices.count)
                row(.favorites, "star.fill", count: devices.filter(\.isFavorite).count)
                row(.recent, "clock.fill", count: nil)
                let missing = devices.filter { ($0.codes ?? []).isEmpty }.count
                if missing > 0 { row(.withoutCode, "exclamationmark.triangle.fill", count: missing) }
            }
            let types = CodeType.allCases.filter { t in devices.contains { LibraryFilter.type(t).includes($0) } }
            if !types.isEmpty {
                Section("Codes") {
                    ForEach(types) { t in
                        row(.type(t), t.symbol, count: devices.filter { LibraryFilter.type(t).includes($0) }.count, tint: t.color)
                    }
                }
            }
            if !homes.isEmpty {
                Section("Homes") {
                    ForEach(homes, id: \.self) { h in row(.home(h), "house.fill", count: devices.filter { $0.home == h }.count) }
                }
            }
            if !rooms.isEmpty {
                Section("Rooms") {
                    ForEach(rooms, id: \.self) { r in row(.room(r), "door.left.hand.closed", count: devices.filter { $0.room == r }.count) }
                }
            }
        }
        .navigationTitle("Pairr")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        #endif
        .toolbar {
            ToolbarItem {
                Button { sheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
    }

    private func row(_ f: LibraryFilter, _ symbol: String, count: Int?, tint: Color = Theme.accent) -> some View {
        Label {
            Text(verbatim: f.title)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .badge(count ?? 0)
        .tag(Optional(f))
    }
}
