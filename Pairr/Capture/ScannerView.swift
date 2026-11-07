#if os(iOS)
import SwiftUI
import VisionKit

/// Live camera scanner for QR codes and printed codes.
struct ScannerView: View {
    var preferred: CodeType?
    var onFound: ([ParsedCode]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(preferred: preferred) { found in
                        onFound(found)
                        dismiss()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        Text("Point the camera at the QR code or the code on the sticker.")
                            .font(.callout.weight(.medium))
                            .multilineTextAlignment(.center)
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(24)
                    }
                } else {
                    ContentUnavailableView("Camera not available",
                                           systemImage: "camera.slash",
                                           description: Text("Allow camera access in Settings, or read the code from a photo instead."))
                }
            }
            .navigationTitle("Scan code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .modalTracked()
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var preferred: CodeType?
    var onFound: ([ParsedCode]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr, .dataMatrix, .aztec]), .text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        vc.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerRepresentable
        private var done = false
        init(parent: DataScannerRepresentable) { self.parent = parent }

        private func handle(_ items: [RecognizedItem]) {
            guard !done else { return }
            var found: [ParsedCode] = []
            for item in items {
                switch item {
                case .barcode(let code):
                    if let payload = code.payloadStringValue, let p = CodeParser.detect(payload, preferred: parent.preferred) {
                        found.append(p)
                    }
                case .text(let text):
                    found += CodeParser.candidates(inText: text.transcript, preferred: parent.preferred)
                @unknown default: break
                }
            }
            // A QR code is certain; text only when it clearly is a code.
            let certain = found.filter { $0.qrPayload != nil }
            let result = certain.isEmpty ? found : certain
            guard !result.isEmpty else { return }
            done = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            parent.onFound(result)
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Give text a moment: QR codes win when both are visible.
            let hasBarcode = allItems.contains { if case .barcode = $0 { return true } else { return false } }
            if hasBarcode { handle(allItems) }
        }

        func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item])
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Printed codes: accept once the text has settled and parses as a known format.
            let texts = allItems.compactMap { item -> String? in
                if case .text(let t) = item { return t.transcript } else { return nil }
            }
            let parsed = texts.flatMap { CodeParser.candidates(inText: $0, preferred: parent.preferred) }
            if parsed.contains(where: { CodeParser.validate($0.type, $0.value, secondary: $0.secondary) == .valid }) {
                handle(allItems)
            }
        }
    }
}
#endif
