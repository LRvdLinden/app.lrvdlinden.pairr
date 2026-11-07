import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// A colour with a dark-mode variant. Compiles on iOS, macOS and watchOS.
    init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
        }
        let (lr, lg, lb) = rgb(light), (dr, dg, db) = rgb(dark)
        #if os(watchOS)
        // watchOS is always dark and has no dynamic UIColor.
        _ = (lr, lg, lb)
        self.init(red: dr, green: dg, blue: db)
        #elseif canImport(UIKit)
        self.init(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: dr, green: dg, blue: db, alpha: 1)
            : UIColor(red: lr, green: lg, blue: lb, alpha: 1) })
        #else
        self.init(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: dr, green: dg, blue: db, alpha: 1)
                : NSColor(red: lr, green: lg, blue: lb, alpha: 1)
        })
        #endif
    }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

enum Theme {
    /// Pairr ocean blue (brand C).
    static let accent = Color(light: 0x0A8FD6, dark: 0x38C8FF)
    static let accentSoft = Color(light: 0xE0F3FC, dark: 0x0F2C44)
    /// Pairr mint, the second brand colour.
    static let mint = Color(light: 0x14A884, dark: 0x2ED3A3)

    /// Colours a device tile can have.
    static let swatches: [String] = [
        "#0A8FD6", "#14A884", "#7B61FF", "#E8505B", "#F2994A",
        "#F2C94C", "#27AE60", "#56CCF2", "#BB6BD9", "#8E8E93",
    ]
}

/// Automatic / Light / Dark.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self { case .system: "Automatic"; case .light: "Light"; case .dark: "Dark" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

/// The language the app actually runs in (two letters; Norwegian Bokmål "nb" → "no").
enum AppLanguage {
    static var code: String {
        let lang = String((Bundle.main.preferredLocalizations.first ?? "en").prefix(2))
        return lang == "nb" || lang == "nn" ? "no" : lang
    }
}

extension Notification.Name {
    /// Posted when the vault key arrives or changes on this device.
    static let vaultKeyChanged = Notification.Name("app.lrvdlinden.pairr.vaultKeyChanged")
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
