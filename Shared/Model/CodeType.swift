import SwiftUI

/// The kinds of pairing code Pairr can keep.
enum CodeType: String, CaseIterable, Codable, Identifiable {
    case homeKit, matter, zigbee, hue, zwave, wifi, pin, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homeKit: "HomeKit"
        case .matter: "Matter"
        case .zigbee: "Zigbee"
        case .hue: "Philips Hue"
        case .zwave: "Z-Wave"
        case .wifi: String(localized: "Wi-Fi password")
        case .pin: String(localized: "PIN code")
        case .other: String(localized: "Other code")
        }
    }

    var symbol: String {
        switch self {
        case .homeKit: "house.fill"
        case .matter: "point.3.connected.trianglepath.dotted"
        case .zigbee: "antenna.radiowaves.left.and.right"
        case .hue: "lightbulb.led.fill"
        case .zwave: "dot.radiowaves.left.and.right"
        case .wifi: "wifi"
        case .pin: "number"
        case .other: "key.fill"
        }
    }

    var color: Color {
        switch self {
        case .homeKit: Color(light: 0xF29D12, dark: 0xFFB340)
        case .matter: Color(light: 0x2F6FE4, dark: 0x6E9CFF)
        case .zigbee: Color(light: 0xE0474F, dark: 0xFF6B72)
        case .hue: Color(light: 0x7B61FF, dark: 0xA594FF)
        case .zwave: Color(light: 0x1696C8, dark: 0x4CC3F0)
        case .wifi: Color(light: 0x27AE60, dark: 0x4CD68A)
        case .pin: Color(light: 0x6B7280, dark: 0xA1A8B3)
        case .other: Theme.accent
        }
    }

    /// Name of the main field.
    var valueLabel: String {
        switch self {
        case .homeKit: String(localized: "Setup code")
        case .matter: String(localized: "Pairing code")
        case .zigbee: String(localized: "Install code")
        case .hue: String(localized: "Serial number")
        case .zwave: String(localized: "DSK")
        case .wifi: String(localized: "Password")
        case .pin: String(localized: "PIN")
        case .other: String(localized: "Code")
        }
    }

    /// Name of the second field, when this type has one.
    var secondaryLabel: String? {
        switch self {
        case .zigbee: String(localized: "IEEE / MAC address")
        case .wifi: String(localized: "Network name")
        case .hue: String(localized: "Bridge setup code")
        default: nil
        }
    }

    var placeholder: String {
        switch self {
        case .homeKit: "123-45-678"
        case .matter: "3497-011-2332"
        case .zigbee: "83FE D340 7A93 9723 A5C6 39B2 6916 D505 C3B5"
        case .hue: "A1B2C3"
        case .zwave: "12345-67890-…"
        case .wifi, .pin, .other: ""
        }
    }

    var secondaryPlaceholder: String {
        switch self {
        case .zigbee: "00:17:88:01:0A:BC:DE:F0"
        case .hue: "123-45-678"
        default: ""
        }
    }

    var hint: String {
        switch self {
        case .homeKit: String(localized: "8 digits, on the sticker, the box or the manual.")
        case .matter: String(localized: "11 or 21 digits, or scan the QR code on the device or box.")
        case .zigbee: String(localized: "The Zigbee 3.0 install code with its IEEE address, often on the device or box.")
        case .hue: String(localized: "6 characters on the fitting of the bulb. Use it in the Hue app to add or reset a lamp by serial number.")
        case .zwave: String(localized: "The 40-digit DSK, or scan the SmartStart QR code.")
        case .wifi: String(localized: "For devices with their own Wi-Fi network or setup hotspot.")
        case .pin: String(localized: "For example the PIN of a lock, alarm or camera.")
        case .other: String(localized: "Any other code you want to keep.")
        }
    }

    /// Use a number pad for this type.
    var isNumeric: Bool { self == .homeKit || self == .matter || self == .zwave || self == .pin }

    /// The order codes appear in on a device.
    var sortOrder: Int { CodeType.allCases.firstIndex(of: self) ?? 99 }
}
