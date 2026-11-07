import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A device's icon tile in its own colour.
struct DeviceIcon: View {
    var kind: DeviceKind
    var color: Color
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// Small coloured badge for a code type.
struct CodeTypeBadge: View {
    var type: CodeType
    var compact = false

    var body: some View {
        Group {
            if compact {
                Image(systemName: type.symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(type.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Label(type.title, systemImage: type.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(type.color, in: Capsule())
            }
        }
        .accessibilityLabel(type.title)
    }
}

/// The HomeKit setup sticker: house glyph + 8 digits in two rows, as the Home app can scan it.
struct HomeKitLabel: View {
    var code: String
    var width: CGFloat = 280

    var body: some View {
        let digits = CodeParser.normalize(.homeKit, code)
        let first = String(digits.prefix(4))
        let second = String(digits.dropFirst(4))
        HStack(spacing: width * 0.07) {
            Image(systemName: "house")
                .font(.system(size: width * 0.2, weight: .regular))
            VStack(spacing: width * 0.01) {
                Text(verbatim: first.map(String.init).joined(separator: " "))
                Text(verbatim: second.map(String.init).joined(separator: " "))
            }
            .font(.system(size: width * 0.13, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, width * 0.08)
        .padding(.vertical, width * 0.06)
        .frame(width: width)
        .background(.white, in: RoundedRectangle(cornerRadius: width * 0.06, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: width * 0.045, style: .continuous)
            .strokeBorder(.black, lineWidth: max(2, width * 0.012))
            .padding(width * 0.025))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "HomeKit \(CodeParser.format(.homeKit, digits))"))
    }
}

extension Image {
    /// An image from PNG/JPEG/HEIC data on any Apple platform.
    init?(imageData: Data) {
        #if canImport(UIKit)
        guard let img = UIImage(data: imageData) else { return nil }
        self.init(uiImage: img)
        #elseif canImport(AppKit)
        guard let img = NSImage(data: imageData) else { return nil }
        self.init(nsImage: img)
        #endif
    }
}

/// Copies a code and clears the clipboard again after a minute.
enum Clipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.setItems([["public.utf8-plain-text": text]],
                                      options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
        #elseif os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        let count = pb.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if pb.changeCount == count { pb.clearContents() }
        }
        #endif
    }
}
