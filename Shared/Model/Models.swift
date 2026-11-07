import Foundation
import SwiftData
import SwiftUI

// All properties have defaults and relationships are optional: CloudKit requires it.

@Model
final class Device {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = DeviceKind.other.rawValue
    var colorHex: String = "#0A8FD6"
    var manufacturer: String = ""
    var model: String = ""
    var serialNumber: String = ""
    var firmware: String = ""
    var home: String = ""
    var room: String = ""
    /// HMAccessory.uniqueIdentifier when imported from the Home app.
    var homeKitID: String = ""
    var isBridged: Bool = false
    var purchaseDate: Date? = nil
    var store: String = ""
    var warrantyUntil: Date? = nil
    var stickerLocation: String = ""
    var notes: String = ""
    var isFavorite: Bool = false
    /// Brand website and its logo (not secret, so not encrypted).
    var logoDomain: String = ""
    @Attribute(.externalStorage) var logoData: Data? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PairingCode.device)
    var codes: [PairingCode]? = []
    @Relationship(deleteRule: .cascade, inverse: \Attachment.device)
    var attachments: [Attachment]? = []
    @Relationship(deleteRule: .cascade, inverse: \CustomField.device)
    var customFields: [CustomField]? = []

    init(name: String = "", kind: DeviceKind = .other) {
        self.name = name
        self.kindRaw = kind.rawValue
    }

    var kind: DeviceKind {
        get { DeviceKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) ?? Theme.accent }

    var sortedCodes: [PairingCode] {
        (codes ?? []).sorted { ($0.type.sortOrder, $0.createdAt) < ($1.type.sortOrder, $1.createdAt) }
    }

    var sortedFields: [CustomField] { (customFields ?? []).sorted { $0.order < $1.order } }

    var sortedAttachments: [Attachment] { (attachments ?? []).sorted { $0.createdAt < $1.createdAt } }

    var codeTypes: [CodeType] {
        Array(Set((codes ?? []).map(\.type))).sorted { $0.sortOrder < $1.sortOrder }
    }

    var displayName: String { name.isEmpty ? String(localized: "Unnamed device") : name }

    /// "Signify · Hue White · Living room"
    var subtitle: String {
        let brand = [manufacturer, model].filter { !$0.isEmpty }.joined(separator: " ")
        return [brand, room].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func touch() { updatedAt = .now }
}

@Model
final class PairingCode {
    var id: UUID = UUID()
    var typeRaw: String = CodeType.other.rawValue
    var label: String = ""
    /// The value, second field, QR payload and QR image — encrypted by CodeVault.
    var sealed: Data? = nil
    var createdAt: Date = Date()
    var device: Device?

    init(type: CodeType, label: String = "") {
        self.typeRaw = type.rawValue
        self.label = label
    }

    var type: CodeType {
        get { CodeType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var secret: CodeSecret? { sealed.flatMap(CodeVault.openSecret) }

    func setSecret(_ secret: CodeSecret) throws {
        sealed = try CodeVault.sealSecret(secret)
    }

    var title: String { label.isEmpty ? type.title : label }
}

enum AttachmentKind: String, Codable {
    case photo, document, link
}

@Model
final class Attachment {
    var id: UUID = UUID()
    var kindRaw: String = AttachmentKind.photo.rawValue
    var name: String = ""
    /// Encrypted file contents (photos of stickers contain codes too).
    @Attribute(.externalStorage) var sealedData: Data? = nil
    var urlString: String = ""
    var contentType: String = ""
    var createdAt: Date = Date()
    var device: Device?

    init(kind: AttachmentKind, name: String) {
        self.kindRaw = kind.rawValue
        self.name = name
    }

    var kind: AttachmentKind { AttachmentKind(rawValue: kindRaw) ?? .document }
    var data: Data? { sealedData.flatMap(CodeVault.open) }
    var url: URL? { URL(string: urlString) }
}

@Model
final class CustomField {
    var id: UUID = UUID()
    var key: String = ""
    var value: String = ""
    var order: Int = 0
    var device: Device?

    init(key: String, value: String, order: Int) {
        self.key = key
        self.value = value
        self.order = order
    }
}

enum PairrStore {
    static let containerID = "iCloud.app.lrvdlinden.pairr"
    static let schema = Schema([Device.self, PairingCode.self, Attachment.self, CustomField.self])

    /// Synced with the user's private iCloud database; falls back to local storage if iCloud can't start.
    static func makeContainer() -> ModelContainer {
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .private(containerID))
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("Pairr: iCloud store unavailable, using local store: \(error)")
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}
