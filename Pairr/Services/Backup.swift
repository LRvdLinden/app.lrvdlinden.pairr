import Foundation
import SwiftData
import CryptoKit
import CommonCrypto

// MARK: Backup file

struct BackupFile: Codable {
    var format = "pairr-backup"
    var version = 1
    var exportedAt = Date()
    var devices: [BackupDevice]
}

struct BackupDevice: Codable {
    var id: UUID
    var name: String
    var kind: String
    var colorHex: String
    var manufacturer: String
    var model: String
    var serialNumber: String
    var firmware: String
    var home: String
    var room: String
    var homeKitID: String
    var isBridged: Bool
    var purchaseDate: Date?
    var store: String
    var warrantyUntil: Date?
    var stickerLocation: String
    var notes: String
    var isFavorite: Bool
    var createdAt: Date
    var codes: [BackupCode]
    var attachments: [BackupAttachment]
    var fields: [BackupField]
}

struct BackupCode: Codable {
    var id: UUID
    var type: String
    var label: String
    var value: String
    var secondary: String
    var qrPayload: String?
    var createdAt: Date
}

struct BackupAttachment: Codable {
    var id: UUID
    var kind: String
    var name: String
    var data: Data?
    var url: String
    var contentType: String
    var createdAt: Date
}

struct BackupField: Codable {
    var key: String
    var value: String
    var order: Int
}

enum BackupError: LocalizedError {
    case wrongPassword, notABackup, tooShortPassword, cannotDecryptCodes
    var errorDescription: String? {
        switch self {
        case .wrongPassword: String(localized: "The password is wrong, or the file is damaged.")
        case .notABackup: String(localized: "This file is not a Pairr backup.")
        case .tooShortPassword: String(localized: "Use a password of at least 8 characters.")
        case .cannotDecryptCodes: String(localized: "Some codes can't be decrypted on this device and were left out.")
        }
    }
}

/// Builds and restores backups. Password backups work on any device;
/// automatic backups are encrypted with the vault key from the iCloud Keychain.
enum Backup {
    private static let passwordMagic = Data("PAIRRBK1".utf8)
    private static let vaultMagic = Data("PAIRRAB1".utf8)

    // MARK: Build

    static func snapshot(_ devices: [Device]) -> BackupFile {
        BackupFile(devices: devices.map { d in
            BackupDevice(
                id: d.id, name: d.name, kind: d.kindRaw, colorHex: d.colorHex,
                manufacturer: d.manufacturer, model: d.model, serialNumber: d.serialNumber,
                firmware: d.firmware, home: d.home, room: d.room, homeKitID: d.homeKitID,
                isBridged: d.isBridged, purchaseDate: d.purchaseDate, store: d.store,
                warrantyUntil: d.warrantyUntil, stickerLocation: d.stickerLocation,
                notes: d.notes, isFavorite: d.isFavorite, createdAt: d.createdAt,
                codes: d.sortedCodes.compactMap { c in
                    guard let s = c.secret else { return nil }
                    return BackupCode(id: c.id, type: c.typeRaw, label: c.label, value: s.value,
                                      secondary: s.secondary, qrPayload: s.qrPayload, createdAt: c.createdAt)
                },
                attachments: d.sortedAttachments.map { a in
                    BackupAttachment(id: a.id, kind: a.kindRaw, name: a.name, data: a.data,
                                     url: a.urlString, contentType: a.contentType, createdAt: a.createdAt)
                },
                fields: d.sortedFields.map { BackupField(key: $0.key, value: $0.value, order: $0.order) })
        })
    }

    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(BackupFile.self, from: data), file.format == "pairr-backup" else {
            throw BackupError.notABackup
        }
        return file
    }

    // MARK: Password encryption (PBKDF2-SHA256 + AES-GCM)

    static func passwordKey(_ password: String, salt: Data) -> SymmetricKey {
        var out = [UInt8](repeating: 0, count: 32)
        let pw = Array(password.utf8)
        _ = salt.withUnsafeBytes { s in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, pw.count,
                                 s.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 210_000, &out, out.count)
        }
        return SymmetricKey(data: out)
    }

    static func sealWithPassword(_ plain: Data, password: String) throws -> Data {
        guard password.count >= 8 else { throw BackupError.tooShortPassword }
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let box = try AES.GCM.seal(plain, using: passwordKey(password, salt: salt))
        guard let combined = box.combined else { throw BackupError.notABackup }
        return passwordMagic + salt + combined
    }

    static func isPasswordBackup(_ data: Data) -> Bool { data.prefix(passwordMagic.count) == passwordMagic }
    static func isVaultBackup(_ data: Data) -> Bool { data.prefix(vaultMagic.count) == vaultMagic }

    static func openWithPassword(_ data: Data, password: String) throws -> BackupFile {
        guard isPasswordBackup(data), data.count > passwordMagic.count + 16 else { throw BackupError.notABackup }
        let salt = data.dropFirst(passwordMagic.count).prefix(16)
        let body = data.dropFirst(passwordMagic.count + 16)
        guard let box = try? AES.GCM.SealedBox(combined: Data(body)),
              let plain = try? AES.GCM.open(box, using: passwordKey(password, salt: Data(salt))) else {
            throw BackupError.wrongPassword
        }
        return try decode(plain)
    }

    // MARK: Vault encryption (automatic backups)

    static func sealWithVault(_ plain: Data) throws -> Data {
        vaultMagic + (try CodeVault.seal(plain))
    }

    static func openWithVault(_ data: Data) throws -> BackupFile {
        guard isVaultBackup(data), let plain = CodeVault.open(Data(data.dropFirst(vaultMagic.count))) else {
            throw BackupError.cannotDecryptCodes
        }
        return try decode(plain)
    }

    // MARK: Restore

    /// Adds devices from a backup. Devices that already exist (same id) are left alone.
    @MainActor
    static func restore(_ file: BackupFile, into context: ModelContext) throws -> (added: Int, skipped: Int) {
        let existing = Set((try? context.fetch(FetchDescriptor<Device>()))?.map(\.id) ?? [])
        var added = 0, skipped = 0
        for b in file.devices {
            if existing.contains(b.id) { skipped += 1; continue }
            let d = Device(name: b.name)
            d.id = b.id
            d.kindRaw = b.kind; d.colorHex = b.colorHex
            d.manufacturer = b.manufacturer; d.model = b.model; d.serialNumber = b.serialNumber
            d.firmware = b.firmware; d.home = b.home; d.room = b.room; d.homeKitID = b.homeKitID
            d.isBridged = b.isBridged; d.purchaseDate = b.purchaseDate; d.store = b.store
            d.warrantyUntil = b.warrantyUntil; d.stickerLocation = b.stickerLocation
            d.notes = b.notes; d.isFavorite = b.isFavorite; d.createdAt = b.createdAt
            context.insert(d)
            var codes: [PairingCode] = []
            for c in b.codes {
                let code = PairingCode(type: CodeType(rawValue: c.type) ?? .other, label: c.label)
                code.id = c.id
                code.createdAt = c.createdAt
                var secret = CodeSecret(value: c.value, secondary: c.secondary, qrPayload: c.qrPayload)
                #if canImport(CoreImage)
                if let p = c.qrPayload { secret.qrPNG = QRCode.pngData(p) }
                #endif
                try code.setSecret(secret)
                context.insert(code)
                codes.append(code)
            }
            d.codes = codes
            var attachments: [Attachment] = []
            for a in b.attachments {
                let att = Attachment(kind: AttachmentKind(rawValue: a.kind) ?? .document, name: a.name)
                att.id = a.id
                att.urlString = a.url
                att.contentType = a.contentType
                att.createdAt = a.createdAt
                if let data = a.data { att.sealedData = try CodeVault.seal(data) }
                context.insert(att)
                attachments.append(att)
            }
            d.attachments = attachments
            var fields: [CustomField] = []
            for f in b.fields {
                let field = CustomField(key: f.key, value: f.value, order: f.order)
                context.insert(field)
                fields.append(field)
            }
            d.customFields = fields
            added += 1
        }
        try context.save()
        return (added, skipped)
    }
}

// MARK: Automatic backup to iCloud Drive

/// Once a week an encrypted backup in iCloud Drive → Pairr. The last 5 are kept.
enum AutoBackup {
    static let enabledKey = "backup.autoEnabled"
    static let lastKey = "backup.lastAutoDate"
    static let keep = 5

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var lastDate: Date? { UserDefaults.standard.object(forKey: lastKey) as? Date }

    /// The app's folder in iCloud Drive, or nil when iCloud Drive is off.
    static func folder() -> URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: PairrStore.containerID) else { return nil }
        let docs = base.appendingPathComponent("Documents/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
    }

    @MainActor
    static func runIfDue(container: ModelContainer) {
        guard isEnabled else { return }
        if let last = lastDate, Date.now.timeIntervalSince(last) < 7 * 24 * 3600 { return }
        Task { @MainActor in
            // Let iCloud finish syncing first after a launch.
            try? await Task.sleep(for: .seconds(20))
            _ = try? await run(container: container)
        }
    }

    /// Writes a backup now. Returns the file, or nil when there is nothing to back up.
    @MainActor
    @discardableResult
    static func run(container: ModelContainer) async throws -> URL? {
        let context = ModelContext(container)
        let devices = (try? context.fetch(FetchDescriptor<Device>())) ?? []
        guard !devices.isEmpty, CodeVault.hasKey else { return nil }
        let data = try Backup.sealWithVault(Backup.encode(Backup.snapshot(devices)))
        guard let dir = await Task.detached(operation: { folder() }).value else { return nil }
        let name = "Pairr-" + ISO8601DateFormatter.string(from: .now, timeZone: .current,
                                                          formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime])
            .replacingOccurrences(of: ":", with: "-") + ".pairrbackup"
        let url = dir.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        UserDefaults.standard.set(Date.now, forKey: lastKey)
        prune(dir)
        return url
    }

    static func list() -> [URL] {
        guard let dir = folder(),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return [] }
        return files.filter { $0.pathExtension == "pairrbackup" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func prune(_ dir: URL) {
        let files = list()
        guard files.count > keep else { return }
        for url in files.dropFirst(keep) { try? FileManager.default.removeItem(at: url) }
    }
}
