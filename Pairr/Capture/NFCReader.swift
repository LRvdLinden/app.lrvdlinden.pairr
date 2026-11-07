#if os(iOS)
import Foundation
import CoreNFC

/// Reads the NDEF record of a HomeKit or Matter NFC tag (iPhone only).
final class NFCReader: NSObject, NFCNDEFReaderSessionDelegate {
    static var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    private var session: NFCNDEFReaderSession?
    private var completion: ((String?) -> Void)?

    func scan(completion: @escaping (String?) -> Void) {
        guard Self.isAvailable else { completion(nil); return }
        self.completion = completion
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = String(localized: "Hold your iPhone near the NFC tag of the device.")
        session?.begin()
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        var value: String?
        for record in messages.flatMap(\.records) {
            if let url = record.wellKnownTypeURIPayload() {
                value = url.absoluteString
            } else {
                let (text, _) = record.wellKnownTypeTextPayload()
                if let text { value = text }
            }
            if value == nil, let raw = String(data: record.payload, encoding: .utf8) {
                value = raw.trimmingCharacters(in: .controlCharacters)
            }
            if value != nil { break }
        }
        finish(value)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        finish(nil)
    }

    private func finish(_ value: String?) {
        guard let completion else { return }
        self.completion = nil
        DispatchQueue.main.async { completion(value) }
    }
}
#endif
