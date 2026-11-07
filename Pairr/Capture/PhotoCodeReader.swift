import Foundation
import Vision
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Finds QR codes and printed codes in a photo of a sticker, box or bulb fitting.
enum PhotoCodeReader {
    static func cgImage(from data: Data, maxPixels: Int = 3000) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func candidates(in data: Data, preferred: CodeType? = nil) async -> [ParsedCode] {
        guard let image = cgImage(from: data) else { return [] }
        return await candidates(in: image, preferred: preferred)
    }

    static func candidates(in image: CGImage, preferred: CodeType? = nil) async -> [ParsedCode] {
        await Task.detached(priority: .userInitiated) {
            var found: [ParsedCode] = []
            func add(_ p: ParsedCode) {
                if !found.contains(where: { $0.type == p.type && $0.value == p.value }) { found.append(p) }
            }

            let barcodes = VNDetectBarcodesRequest()
            barcodes.symbologies = [.qr, .dataMatrix, .aztec, .code128]
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .accurate
            text.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([barcodes, text])

            for obs in barcodes.results ?? [] {
                if let payload = obs.payloadStringValue, let p = CodeParser.detect(payload, preferred: preferred) { add(p) }
            }
            let lines = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            for p in CodeParser.candidates(inText: lines.joined(separator: "\n"), preferred: preferred) { add(p) }
            // Lines read one by one catch codes that were split over lines.
            for line in lines {
                for p in CodeParser.candidates(inText: line, preferred: preferred) { add(p) }
            }
            return found
        }.value
    }

    /// Downscaled JPEG for attachments (keeps iCloud storage small).
    static func compressedJPEG(_ data: Data, maxPixels: Int = 2048) -> Data? {
        guard let image = cgImage(from: data, maxPixels: maxPixels) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}
