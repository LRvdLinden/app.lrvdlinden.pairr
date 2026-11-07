import Foundation
import CloudKit

/// Whether iCloud is available, and whether Pairr data already exists there
/// (for example after reinstalling the app), so the app can say it is restoring.
@MainActor
@Observable
final class CloudStatus {
    static let shared = CloudStatus()

    enum Account { case unknown, available, noAccount, restricted, temporarilyUnavailable }

    var account: Account = .unknown
    /// True when the SwiftData zone exists in the private iCloud database.
    var hasCloudData = false
    var checked = false

    private let container = CKContainer(identifier: PairrStore.containerID)

    func refresh() async {
        do {
            switch try await container.accountStatus() {
            case .available: account = .available
            case .noAccount: account = .noAccount
            case .restricted: account = .restricted
            case .temporarilyUnavailable: account = .temporarilyUnavailable
            default: account = .unknown
            }
        } catch {
            account = .unknown
        }
        if account == .available {
            let db = container.privateCloudDatabase
            let zones = (try? await db.allRecordZones()) ?? []
            if let zone = zones.first(where: { $0.zoneID.zoneName == "com.apple.coredata.cloudkit.zone" }) {
                // The zone stays after everything was deleted, so look for an actual record.
                let changes = try? await db.recordZoneChanges(inZoneWith: zone.zoneID, since: nil,
                                                               desiredKeys: [], resultsLimit: 5)
                hasCloudData = !(changes?.modificationResultsByID.isEmpty ?? true)
            } else {
                hasCloudData = false
            }
        }
        checked = true
    }

    var accountText: String {
        switch account {
        case .available: String(localized: "On — synced with your iCloud")
        case .noAccount: String(localized: "Not signed in to iCloud")
        case .restricted: String(localized: "iCloud is restricted on this device")
        case .temporarilyUnavailable: String(localized: "iCloud is temporarily unavailable")
        case .unknown: String(localized: "Checking…")
        }
    }
}
