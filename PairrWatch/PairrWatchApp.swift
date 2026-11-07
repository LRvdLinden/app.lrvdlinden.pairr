import SwiftUI
import SwiftData

@main
struct PairrWatchApp: App {
    private let container = PairrStore.makeContainer()

    init() {
        KeySync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
    }
}

struct WatchRootView: View {
    @Query(sort: \Device.name) private var devices: [Device]
    @State private var hasKey = CodeVault.hasKey
    @State private var search = ""

    private var filtered: [Device] {
        let q = search.trimmed.lowercased()
        let list = q.isEmpty ? devices : devices.filter {
            [$0.name, $0.room, $0.manufacturer].contains { $0.lowercased().contains(q) }
        }
        return list.sorted { ($0.isFavorite ? 0 : 1, $0.displayName) < ($1.isFavorite ? 0 : 1, $1.displayName) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !hasKey {
                    Label("Open Pairr on your iPhone to unlock your codes here.", systemImage: "iphone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { d in
                    NavigationLink {
                        WatchDeviceView(device: d)
                    } label: {
                        HStack(spacing: 10) {
                            DeviceAvatar(device: d, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: d.displayName).font(.headline).lineLimit(1)
                                if !d.room.isEmpty {
                                    Text(verbatim: d.room).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if devices.isEmpty {
                    ContentUnavailableView("No devices", systemImage: "key.viewfinder",
                                           description: Text("Add devices in Pairr on your iPhone."))
                }
            }
            .navigationTitle("Pairr")
            .searchable(text: $search)
        }
        .onReceive(NotificationCenter.default.publisher(for: .vaultKeyChanged)) { _ in
            CodeVault.reload()
            hasKey = CodeVault.hasKey
        }
        .task {
            KeySync.shared.requestKeyIfNeeded()
            hasKey = CodeVault.hasKey
        }
    }
}

struct WatchDeviceView: View {
    let device: Device

    var body: some View {
        List {
            ForEach(device.sortedCodes) { code in
                NavigationLink {
                    WatchCodeView(code: code)
                } label: {
                    HStack(spacing: 8) {
                        CodeTypeBadge(type: code.type, compact: true)
                        Text(verbatim: code.title).lineLimit(1)
                    }
                }
            }
            if (device.codes ?? []).isEmpty {
                Text("No codes yet").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(device.displayName)
    }
}

struct WatchCodeView: View {
    let code: PairingCode
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let s = code.secret {
                    if let png = s.qrPNG, let image = Image(imageData: png) {
                        image.resizable().interpolation(.none).scaledToFit()
                            .padding(8)
                            .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    } else if code.type == .homeKit {
                        HomeKitLabel(code: s.value, width: 160)
                    }
                    Text(verbatim: revealed ? CodeParser.format(code.type, s.value) : String(repeating: "•", count: 8))
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .onTapGesture { revealed.toggle() }
                    if !revealed {
                        Text("Tap to show").font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Label("Open Pairr on your iPhone to unlock this code.", systemImage: "lock.iphone")
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(code.type.title)
    }
}
