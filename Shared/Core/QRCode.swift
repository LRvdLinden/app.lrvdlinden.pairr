#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Draws QR codes (iPhone, iPad and Mac; the watch shows the stored PNG).
enum QRCode {
    private static let context = CIContext()

    static func cgImage(_ payload: String, scale: CGFloat = 14) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        return context.createCGImage(output, from: output.extent)
    }

    static func image(_ payload: String) -> Image? {
        cgImage(payload).map { Image(decorative: $0, scale: 1) }
    }

    static func pngData(_ payload: String) -> Data? {
        guard let cg = cgImage(payload, scale: 10) else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
#endif
