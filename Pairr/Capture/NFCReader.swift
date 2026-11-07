#if os(iOS)
import Foundation
import CoreNFC

/// Reads the NDEF record of a HomeKit or Matter NFC tag (iPhone only).
///
/// Uses a tag reader session (entitlement format "TAG"): since the iOS 27 SDK
/// the NDEF-only format is no longer accepted by App Store Connect.
final class NFCReader: NSObject, NFCTagReaderSessionDelegate {
    static var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    private var session: NFCTagReaderSession?
    private var completion: ((String?) -> Void)?

    func scan(completion: @escaping (String?) -> Void) {
        guard Self.isAvailable else { completion(nil); return }
        self.completion = completion
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
        session?.alertMessage = String(localized: "Hold your iPhone near the NFC tag of the device.")
        session?.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        finish(nil)
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        let ndefTag: NFCNDEFTag
        switch tag {
        case .miFare(let t): ndefTag = t
        case .iso7816(let t): ndefTag = t
        case .iso15693(let t): ndefTag = t
        case .feliCa(let t): ndefTag = t
        @unknown default:
            session.invalidate(errorMessage: String(localized: "This tag is not supported."))
            return
        }
        session.connect(to: tag) { [weak self] error in
            guard error == nil else {
                session.invalidate(errorMessage: String(localized: "Couldn't read the tag. Try again."))
                return
            }
            ndefTag.readNDEF { message, _ in
                let value = message.flatMap(Self.text(from:))
                if value != nil {
                    session.alertMessage = String(localized: "Code read.")
                    session.invalidate()
                } else {
                    session.invalidate(errorMessage: String(localized: "No code found on this tag."))
                }
                self?.finish(value)
            }
        }
    }

    private static func text(from message: NFCNDEFMessage) -> String? {
        for record in message.records {
            if let url = record.wellKnownTypeURIPayload() { return url.absoluteString }
            let (text, _) = record.wellKnownTypeTextPayload()
            if let text, !text.isEmpty { return text }
            if let raw = String(data: record.payload, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters), !raw.isEmpty { return raw }
        }
        return nil
    }

    private func finish(_ value: String?) {
        guard let completion else { return }
        self.completion = nil
        DispatchQueue.main.async { completion(value) }
    }
}
#endif
