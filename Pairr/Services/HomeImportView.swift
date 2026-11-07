#if os(iOS)
import SwiftUI
import SwiftData
import HomeKit

/// Reads homes, rooms and accessories from the Home app. Pairr never changes the home.
@Observable
final class HomeKitBrowser: NSObject, HMHomeManagerDelegate {
    private let manager = HMHomeManager()
    var homes: [HMHome] = []
    var loaded = false
    var authorized = true

    override init() {
        super.init()
        manager.delegate = self
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        homes = manager.homes.sorted { $0.isPrimary && !$1.isPrimary }
        loaded = true
    }

    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        authorized = status.contains(.authorized) || !status.contains(.determined)
        if status.contains(.determined), !status.contains(.authorized) { loaded = true }
    }
}

struct HomeImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var devices: [Device]
    @State private var browser = HomeKitBrowser()
    @State private var selected: Set<UUID> = []
    @State private var hideBridged = true
    @State private var importing = false
    @State private var result: String?

    var body: some View {
        NavigationStack {
            Group {
                if !browser.loaded {
                    ProgressView("Reading your homes…")
                } else if !browser.authorized {
                    ContentUnavailableView("No access to your home",
                                           systemImage: "house.slash",
                                           description: Text("Allow Pairr to use Home data in Settings → Privacy & Security → HomeKit."))
                } else if browser.homes.isEmpty {
                    ContentUnavailableView("No homes found", systemImage: "house",
                                           description: Text("Set up a home in the Home app first."))
                } else {
                    list
                }
            }
            .navigationTitle("Import from the Home app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { Task { await runImport() } }
                        .disabled(selected.isEmpty || importing)
                }
            }
            .alert("Import finished", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil; dismiss() } })) {
                Button("OK") { result = nil; dismiss() }
            } message: {
                Text(verbatim: result ?? "")
            }
            .overlay { if importing { ProgressView().controlSize(.large) } }
        }
        .modalTracked()
    }

    private var list: some View {
        List {
            Section {
                Toggle("Hide accessories behind a bridge", isOn: $hideBridged)
                Button(allVisibleSelected ? LocalizedStringKey("Select none") : LocalizedStringKey("Select all")) {
                    let ids = Set(visibleAccessories.map(\.uniqueIdentifier))
                    selected = allVisibleSelected ? [] : ids
                }
            } footer: {
                Text("Pairr copies the name, room, manufacturer and model. The setup codes themselves are not stored by HomeKit, so you add those afterwards.")
            }
            ForEach(browser.homes, id: \.uniqueIdentifier) { home in
                Section(home.name) {
                    ForEach(accessories(in: home), id: \.uniqueIdentifier) { acc in
                        accessoryRow(acc)
                    }
                }
            }
        }
    }

    private func accessories(in home: HMHome) -> [HMAccessory] {
        home.accessories
            .filter { !hideBridged || !$0.isBridged }
            .sorted { ($0.room?.name ?? "", $0.name) < ($1.room?.name ?? "", $1.name) }
    }

    private var visibleAccessories: [HMAccessory] { browser.homes.flatMap { accessories(in: $0) } }
    private var allVisibleSelected: Bool {
        let ids = visibleAccessories.map(\.uniqueIdentifier)
        return !ids.isEmpty && ids.allSatisfy(selected.contains)
    }

    private func accessoryRow(_ acc: HMAccessory) -> some View {
        let isOn = selected.contains(acc.uniqueIdentifier)
        let known = devices.contains { $0.homeKitID == acc.uniqueIdentifier.uuidString }
        return Button {
            if isOn { selected.remove(acc.uniqueIdentifier) } else { selected.insert(acc.uniqueIdentifier) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Theme.accent : .secondary)
                DeviceIcon(kind: Self.kind(for: acc), color: Theme.accent, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: acc.name).foregroundStyle(.primary)
                    Text(verbatim: [acc.room?.name, acc.manufacturer].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if known {
                    Text("In Pairr").font(.caption.weight(.semibold)).foregroundStyle(Theme.mint)
                }
            }
        }
    }

    // MARK: Import

    @MainActor
    private func runImport() async {
        importing = true
        defer { importing = false }
        var added = 0, updated = 0
        for home in browser.homes {
            for acc in home.accessories where selected.contains(acc.uniqueIdentifier) {
                let serial = await Self.serialNumber(of: acc)
                let id = acc.uniqueIdentifier.uuidString
                // Same accessory, or the same physical device paired again (matched on serial number).
                let existing = devices.first { $0.homeKitID == id }
                    ?? devices.first { !serial.isEmpty && $0.serialNumber == serial
                        && ($0.manufacturer.isEmpty || $0.manufacturer == (acc.manufacturer ?? "")) }
                let d = existing ?? Device(name: acc.name, kind: Self.kind(for: acc))
                if existing == nil {
                    context.insert(d)
                    added += 1
                } else {
                    updated += 1
                }
                d.homeKitID = id
                if d.name.isEmpty || existing == nil { d.name = acc.name }
                d.home = home.name
                d.room = acc.room?.name ?? d.room
                if let m = acc.manufacturer, !m.isEmpty { d.manufacturer = m }
                if let m = acc.model, !m.isEmpty { d.model = m }
                if let f = acc.firmwareVersion, !f.isEmpty { d.firmware = f }
                if !serial.isEmpty { d.serialNumber = serial }
                d.isBridged = acc.isBridged
                if existing == nil { d.kind = Self.kind(for: acc) }
                d.touch()
            }
        }
        try? context.save()
        result = String(format: String(localized: "%lld added, %lld updated."), added, updated)
    }

    /// HAP characteristic "Serial Number" (HMCharacteristicTypeSerialNumber is deprecated).
    private static let serialNumberType = "00000030-0000-1000-8000-0026BB765291"

    /// The serial number from the Accessory Information service, read with a short timeout.
    private static func serialNumber(of acc: HMAccessory) async -> String {
        let characteristic = acc.services
            .flatMap(\.characteristics)
            .first { $0.characteristicType == Self.serialNumberType }
        guard let characteristic else { return "" }
        if let value = characteristic.value as? String, !value.isEmpty { return value }
        guard acc.isReachable else { return "" }
        return await withTaskGroup(of: String.self) { group in
            group.addTask {
                try? await characteristic.readValue()
                return (characteristic.value as? String) ?? ""
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return ""
            }
            let first = await group.next() ?? ""
            group.cancelAll()
            return first
        }
    }

    static func kind(for acc: HMAccessory) -> DeviceKind {
        let type = acc.category.categoryType
        if #available(iOS 18.0, *) {
            switch type {
            case HMAccessoryCategoryTypeWiFiRouter: return .router
            case HMAccessoryCategoryTypeTelevision: return .tv
            case HMAccessoryCategoryTypeSpeaker, HMAccessoryCategoryTypeAirPort: return .speaker
            default: break
            }
        }
        return switch type {
        case HMAccessoryCategoryTypeLightbulb: .light
        case HMAccessoryCategoryTypeOutlet: .plug
        case HMAccessoryCategoryTypeSwitch: .lightSwitch
        case HMAccessoryCategoryTypeProgrammableSwitch: .button
        case HMAccessoryCategoryTypeSensor: .sensor
        case HMAccessoryCategoryTypeDoorLock: .lock
        case HMAccessoryCategoryTypeThermostat, HMAccessoryCategoryTypeAirHeater: .thermostat
        case HMAccessoryCategoryTypeIPCamera: .camera
        case HMAccessoryCategoryTypeVideoDoorbell: .doorbell
        case HMAccessoryCategoryTypeBridge: .bridge
        case HMAccessoryCategoryTypeFan: .fan
        case HMAccessoryCategoryTypeAirPurifier, HMAccessoryCategoryTypeAirHumidifier, HMAccessoryCategoryTypeAirDehumidifier: .airPurifier
        case HMAccessoryCategoryTypeGarageDoorOpener: .garage
        case HMAccessoryCategoryTypeWindowCovering: .blinds
        case HMAccessoryCategoryTypeDoor, HMAccessoryCategoryTypeWindow: .contact
        case HMAccessoryCategoryTypeRangeExtender: .router
        case HMAccessoryCategoryTypeSecuritySystem: .camera
        default: .other
        }
    }
}
#endif
