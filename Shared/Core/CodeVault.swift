import Foundation
import CryptoKit
import Security

/// The decrypted contents of a pairing code.
struct CodeSecret: Codable, Hashable {
    var value: String
    var secondary: String = ""
    var qrPayload: String? = nil
    /// A ready-made QR image, so the Apple Watch (no Core Image) can show it too.
    var qrPNG: Data? = nil
}

enum VaultError: LocalizedError {
    case noKey, badData
    var errorDescription: String? {
        switch self {
        case .noKey: String(localized: "This device doesn't have the key to your codes yet.")
        case .badData: String(localized: "This code couldn't be decrypted.")
        }
    }
}

/// Encrypts codes and attachments with AES-GCM.
///
/// The 256-bit key lives in the iCloud Keychain (synchronizable), so it survives
/// deleting and reinstalling the app and reaches the user's other devices. The
/// Apple Watch gets it from the iPhone over WatchConnectivity.
enum CodeVault {
    private static let service = "app.lrvdlinden.pairr.vault"
    private static let account = "master-key-v1"
    private static let magic = Data("PV1".utf8)
    private static let lock = NSLock()
    private static var cachedKey: SymmetricKey?

    static var accessGroup: String? {
        (Bundle.main.object(forInfoDictionaryKey: "PairrKeychainGroup") as? String).flatMap { $0.contains("$(") ? nil : $0 }
    }

    static var hasKey: Bool { loadKey() != nil }

    // MARK: Key

    private static func query(group: Bool) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if group, let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        #if os(macOS)
        q[kSecUseDataProtectionKeychain as String] = true
        #endif
        return q
    }

    static func loadKey() -> SymmetricKey? {
        lock.lock(); defer { lock.unlock() }
        if let cachedKey { return cachedKey }
        for group in [true, false] {
            var q = query(group: group)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            q[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
            var out: AnyObject?
            if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data, data.count == 32 {
                cachedKey = SymmetricKey(data: data)
                return cachedKey
            }
        }
        return nil
    }

    @discardableResult
    private static func storeKey(_ data: Data, synchronizable: Bool) -> Bool {
        for group in [true, false] {
            var q = query(group: group)
            q[kSecAttrSynchronizable as String] = synchronizable ? kCFBooleanTrue : kCFBooleanFalse
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            q[kSecAttrLabel as String] = "Pairr"
            let status = SecItemAdd(q as CFDictionary, nil)
            if status == errSecSuccess { return true }
            if status == errSecDuplicateItem {
                var match = query(group: group)
                match[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
                if SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecSuccess { return true }
            }
        }
        return false
    }

    /// The key, created on first use (iPhone, iPad and Mac only).
    static func keyOrCreate() throws -> SymmetricKey {
        if let key = loadKey() { return key }
        #if os(watchOS)
        throw VaultError.noKey
        #else
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        guard storeKey(data, synchronizable: true) else { throw VaultError.noKey }
        lock.lock(); cachedKey = key; lock.unlock()
        NotificationCenter.default.post(name: .vaultKeyChanged, object: nil)
        return key
        #endif
    }

    static func exportKey() -> Data? { loadKey()?.withUnsafeBytes { Data($0) } }

    /// Saves a key received from the iPhone (Apple Watch).
    static func importKey(_ data: Data) {
        guard data.count == 32 else { return }
        if let current = exportKey(), current == data { return }
        storeKey(data, synchronizable: false)
        lock.lock(); cachedKey = SymmetricKey(data: data); lock.unlock()
        NotificationCenter.default.post(name: .vaultKeyChanged, object: nil)
    }

    /// Clears the cached key so the next read goes to the keychain again.
    static func reload() {
        lock.lock(); cachedKey = nil; lock.unlock()
    }

    private static func fingerprint(_ key: SymmetricKey) -> Data {
        Data(key.withUnsafeBytes { SHA256.hash(data: Data($0)) }.prefix(4))
    }

    // MARK: Seal / open

    static func seal(_ plain: Data) throws -> Data {
        let key = try keyOrCreate()
        guard let combined = try AES.GCM.seal(plain, using: key).combined else { throw VaultError.badData }
        return magic + fingerprint(key) + combined
    }

    static func open(_ sealed: Data) -> Data? {
        guard sealed.count > magic.count + 4, sealed.prefix(magic.count) == magic, let key = loadKey() else { return nil }
        let fp = sealed.dropFirst(magic.count).prefix(4)
        guard Data(fp) == fingerprint(key) else { return nil }
        let body = sealed.dropFirst(magic.count + 4)
        guard let box = try? AES.GCM.SealedBox(combined: Data(body)) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    /// True when the data was sealed with a key this device doesn't have.
    static func isForeign(_ sealed: Data) -> Bool {
        guard sealed.count > magic.count + 4, let key = loadKey() else { return true }
        return Data(sealed.dropFirst(magic.count).prefix(4)) != fingerprint(key)
    }

    static func sealSecret(_ secret: CodeSecret) throws -> Data {
        try seal(JSONEncoder().encode(secret))
    }

    static func openSecret(_ sealed: Data) -> CodeSecret? {
        open(sealed).flatMap { try? JSONDecoder().decode(CodeSecret.self, from: $0) }
    }
}
