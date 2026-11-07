import SwiftUI
import SwiftData

enum DeviceSort: String, CaseIterable, Identifiable {
    case name, room, recent
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self { case .name: "Name"; case .room: "Room"; case .recent: "Recently added" }
    }
}

struct DeviceListView: View {
    let filter: LibraryFilter
    @Binding var selection: UUID?
    @Binding var sheet: ActiveSheet?
    /// iPhone: a plain navigation stack with a filter menu instead of the sidebar.
    var compact = false
    var filterChoice: Binding<LibraryFilter?>? = nil

    @Environment(\.modelContext) private var context
    @Query(sort: \Device.name) private var all: [Device]
    @State private var search = ""
    @State private var capture: CaptureSource?
    @State private var pendingDelete: Device?
    @State private var cloud = CloudStatus.shared
    @AppStorage("ui.sort") private var sort: DeviceSort = .name
    @AppStorage("ui.groupByRoom") private var groupByRoom = false

    private var items: [Device] {
        let q = search.trimmed.lowercased()
        let list = all.filter { d in
            guard filter.includes(d) else { return false }
            guard !q.isEmpty else { return true }
            return [d.name, d.manufacturer, d.model, d.room, d.home, d.serialNumber, d.notes]
                .contains { $0.lowercased().contains(q) }
        }
        switch sort {
        case .name: return list.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .room: return list.sorted { ($0.room, $0.displayName) < ($1.room, $1.displayName) }
        case .recent: return list.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var grouped: [(String, [Device])] {
        let dict = Dictionary(grouping: items) { $0.room.isEmpty ? String(localized: "No room") : $0.room }
        return dict.keys.sorted().map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        List(selection: compact ? .constant(nil) : $selection) {
            if groupByRoom {
                ForEach(grouped, id: \.0) { room, devices in
                    Section(room) { ForEach(devices) { row($0) } }
                }
            } else {
                ForEach(items) { row($0) }
            }
        }
        .overlay { emptyState }
        .searchable(text: $search, prompt: Text("Search devices"))
        .navigationTitle(filter.title)
        #if os(iOS)
        .safeAreaInset(edge: .bottom) { scanBar }
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) { addMenu }
            if compact, let filterChoice {
                ToolbarItem(placement: .primaryAction) { filterMenu(filterChoice) }
            }
            ToolbarItem {
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(DeviceSort.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Group by room", isOn: $groupByRoom)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button { sheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
            }
            #endif
        }
        .codeCapture(source: $capture) { parsed in sheet = .newDevice(parsed) }
        .confirmationDialog("Delete this device?", isPresented: Binding(get: { pendingDelete != nil },
                                                                       set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { device in
            Button("Delete", role: .destructive) { delete(device) }
        } message: { _ in
            Text("Its codes and attachments are deleted on all your devices.")
        }
    }

    @ViewBuilder
    private func rowContent(_ device: Device) -> some View {
        if compact {
            NavigationLink(value: device.id) { DeviceRow(device: device) }
        } else {
            DeviceRow(device: device).tag(device.id)
        }
    }

    private func row(_ device: Device) -> some View {
        rowContent(device)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { pendingDelete = device } label: { Label("Delete", systemImage: "trash") }
            }
            .swipeActions(edge: .leading) {
                Button { device.isFavorite.toggle(); device.touch() } label: {
                    Label(device.isFavorite ? LocalizedStringKey("Remove favorite") : LocalizedStringKey("Favorite"), systemImage: device.isFavorite ? "star.slash" : "star")
                }
                .tint(.yellow)
            }
            .contextMenu {
                Button { device.isFavorite.toggle(); device.touch() } label: {
                    Label(device.isFavorite ? LocalizedStringKey("Remove favorite") : LocalizedStringKey("Favorite"), systemImage: "star")
                }
                Button(role: .destructive) { pendingDelete = device } label: { Label("Delete", systemImage: "trash") }
            }
    }

    #if os(iOS)
    /// A big, always visible button to scan a code with the camera.
    private var scanBar: some View {
        Button { capture = .camera } label: {
            Label("Scan a code", systemImage: "qrcode.viewfinder")
                .font(.headline)
                .frame(maxWidth: 420)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    #endif

    /// Filters for iPhone, where the sidebar isn't shown.
    private func filterMenu(_ choice: Binding<LibraryFilter?>) -> some View {
        let types = CodeType.allCases.filter { t in all.contains { LibraryFilter.type(t).includes($0) } }
        let homes = Array(Set(all.map(\.home).filter { !$0.isEmpty })).sorted()
        let rooms = Array(Set(all.map(\.room).filter { !$0.isEmpty })).sorted()
        return Menu {
            Picker("Show", selection: choice) {
                Text(verbatim: LibraryFilter.all.title).tag(Optional(LibraryFilter.all))
                Text(verbatim: LibraryFilter.favorites.title).tag(Optional(LibraryFilter.favorites))
                Text(verbatim: LibraryFilter.recent.title).tag(Optional(LibraryFilter.recent))
                Text(verbatim: LibraryFilter.withoutCode.title).tag(Optional(LibraryFilter.withoutCode))
            }
            if !types.isEmpty {
                Picker("Codes", selection: choice) {
                    ForEach(types) { t in Label(t.title, systemImage: t.symbol).tag(Optional(LibraryFilter.type(t))) }
                }
            }
            if !homes.isEmpty {
                Picker("Homes", selection: choice) {
                    ForEach(homes, id: \.self) { h in Text(verbatim: h).tag(Optional(LibraryFilter.home(h))) }
                }
            }
            if !rooms.isEmpty {
                Picker("Rooms", selection: choice) {
                    ForEach(rooms, id: \.self) { r in Text(verbatim: r).tag(Optional(LibraryFilter.room(r))) }
                }
            }
        } label: {
            Label("Filter", systemImage: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private var addMenu: some View {
        Menu {
            Button { sheet = .newDevice(nil) } label: { Label("New device", systemImage: "plus.square") }
            CaptureButtons(source: $capture)
            #if os(iOS)
            Button { sheet = .homeImport } label: { Label("Import from the Home app", systemImage: "house") }
            #endif
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if all.isEmpty {
            if cloud.hasCloudData {
                ContentUnavailableView {
                    Label("Restoring from iCloud", systemImage: "icloud.and.arrow.down")
                } description: {
                    Text("Your devices and codes are coming back from iCloud. This can take a moment.")
                } actions: {
                    ProgressView()
                }
            } else {
                ContentUnavailableView {
                    Label("No devices yet", systemImage: "key.viewfinder")
                } description: {
                    Text("Add a device and its pairing code: scan it, read it from a photo or import your accessories from the Home app.")
                } actions: {
                    Button("Add device") { sheet = .newDevice(nil) }
                        .buttonStyle(.borderedProminent)
                }
            }
        } else if items.isEmpty {
            if search.isEmpty {
                ContentUnavailableView("Nothing here", systemImage: "tray",
                                       description: Text("No devices match this filter."))
            } else {
                ContentUnavailableView.search(text: search)
            }
        }
    }

    private func delete(_ device: Device) {
        if selection == device.id { selection = nil }
        context.delete(device)
        try? context.save()
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            DeviceIcon(kind: device.kind, color: device.color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: device.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if !device.subtitle.isEmpty {
                    Text(verbatim: device.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                ForEach(device.codeTypes) { CodeTypeBadge(type: $0, compact: true) }
            }
            if device.isFavorite {
                Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, 2)
    }
}
