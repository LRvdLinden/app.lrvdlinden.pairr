import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Product details found online for a scanned code.
struct DeviceInfo: Equatable {
    var manufacturer = ""
    var productName = ""
    var model = ""
    var kind: DeviceKind?
    var productURL: URL?
    var manualURL: URL?
    var supportURL: URL?
    /// Website of the manufacturer, used for its logo.
    var brandDomain: String?
    /// Where the details came from, shown to the user.
    var source = ""
}

/// Looks up product details and brand logos.
///
/// - Matter: the public Distributed Compliance Ledger (DCL) of the Connectivity Standards
///   Alliance, by vendor and product ID from the QR code.
/// - Zigbee: the manufacturer from the IEEE address (OUI) for brands that make their own radios.
/// - Logos: the apple-touch-icon or favicon on the manufacturer's own website.
enum DeviceLookup {
    static let enabledKey = "lookup.online"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    private static let dcl = URL(string: "https://on.dcl.csa-iot.org")!
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 15
        c.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: c)
    }()

    // MARK: All sources

    /// Everything Pairr can find for a parsed code. Never throws; returns nil when nothing is known.
    static func info(for code: ParsedCode) async -> DeviceInfo? {
        var info = DeviceInfo()
        var found = false

        if let category = code.suggestedKind { info.kind = category; found = true }

        switch code.type {
        case .matter:
            if isEnabled, let vid = code.vendorID, let pid = code.productID, vid < 0xFFF1 {
                if let m = await matter(vendorID: vid, productID: pid) {
                    info = merge(info, m)
                    found = true
                }
            }
        case .hue:
            info.manufacturer = "Signify"
            info.productName = "Philips Hue"
            info.kind = info.kind ?? .light
            info.brandDomain = "philips-hue.com"
            info.source = "Philips Hue"
            found = true
        case .zigbee:
            if let brand = zigbeeBrand(ieee: code.secondary) {
                info.manufacturer = brand.name
                info.brandDomain = brand.domain
                info.source = String(localized: "Zigbee address")
                found = true
            }
        default:
            break
        }
        return found ? info : nil
    }

    private static func merge(_ a: DeviceInfo, _ b: DeviceInfo) -> DeviceInfo {
        var r = b
        if r.kind == nil { r.kind = a.kind }
        return r
    }

    // MARK: Matter (DCL)

    static func matter(vendorID: Int, productID: Int) async -> DeviceInfo? {
        async let vendor = json(dcl.appendingPathComponent("dcl/vendorinfo/vendors/\(vendorID)"))
        async let model = json(dcl.appendingPathComponent("dcl/model/models/\(vendorID)/\(productID)"))
        let v = (await vendor).flatMap { $0["vendorInfo"] as? [String: Any] ?? $0 }
        let m = (await model).flatMap { $0["model"] as? [String: Any] ?? $0 }
        guard v != nil || m != nil else { return nil }

        var info = DeviceInfo(source: String(localized: "Matter register (CSA)"))
        if let v {
            let preferred = (v["companyPreferredName"] as? String)?.trimmed ?? ""
            let name = (v["vendorName"] as? String)?.trimmed ?? ""
            info.manufacturer = preferred.isEmpty ? name : preferred
            if let landing = url(v["vendorLandingPageURL"] ?? v["vendorLandingPageUrl"]) {
                info.brandDomain = landing.host().map(cleanHost)
            }
        }
        if let m {
            info.productName = (m["productName"] as? String)?.trimmed ?? ""
            let label = (m["productLabel"] as? String)?.trimmed ?? ""
            let part = (m["partNumber"] as? String)?.trimmed ?? ""
            info.model = part.isEmpty ? label : part
            if let type = (m["deviceTypeID"] ?? m["deviceTypeId"]) as? Int { info.kind = kind(forMatterDeviceType: type) }
            info.productURL = url(m["productUrl"] ?? m["productURL"])
            info.manualURL = url(m["userManualUrl"] ?? m["userManualURL"])
            info.supportURL = url(m["supportUrl"] ?? m["supportURL"])
            if info.brandDomain == nil { info.brandDomain = (info.productURL ?? info.supportURL)?.host().map(cleanHost) }
        }
        if info.brandDomain == nil { info.brandDomain = domain(forManufacturer: info.manufacturer) }
        return info
    }

    private static func json(_ url: URL) async -> [String: Any]? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func url(_ value: Any?) -> URL? {
        guard let s = (value as? String)?.trimmed, !s.isEmpty, let u = URL(string: s), u.scheme == "https" else { return nil }
        return u
    }

    private static func cleanHost(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Matter device type IDs (Matter Device Library) → Pairr icon.
    static func kind(forMatterDeviceType id: Int) -> DeviceKind? {
        switch id {
        case 0x0100, 0x0101, 0x010C, 0x010D: .light
        case 0x010A, 0x010B: .plug
        case 0x0103, 0x0104, 0x0105: .lightSwitch
        case 0x000F: .button
        case 0x0015: .contact
        case 0x0107: .motion
        case 0x0302, 0x0307, 0x0305, 0x002C: .climate
        case 0x0106, 0x0043, 0x0041: .sensor
        case 0x000A: .lock
        case 0x0301, 0x0072: .thermostat
        case 0x0202: .blinds
        case 0x002B: .fan
        case 0x002D: .airPurifier
        case 0x0076: .smoke
        case 0x000E, 0x0016: .bridge
        case 0x0023, 0x0024, 0x0028, 0x0029: .tv
        case 0x0022: .speaker
        case 0x0074: .robot
        case 0x0142, 0x0143: .camera
        case 0x0144: .doorbell
        default: nil
        }
    }

    // MARK: Zigbee

    /// IEEE OUIs of brands that use their own registered prefix.
    private static let zigbeeOUIs: [String: (name: String, domain: String)] = [
        "001788": ("Signify (Philips Hue)", "philips-hue.com"),
        "00158D": ("Aqara", "aqara.com"),
        "54EF44": ("Aqara", "aqara.com"),
        "04CF8C": ("Aqara", "aqara.com"),
        "001FEE": ("ubisys", "ubisys.de"),
        "000D6F": ("Silicon Labs", "silabs.com"),
        "00124B": ("Texas Instruments", "ti.com"),
    ]

    static func zigbeeBrand(ieee: String) -> (name: String, domain: String)? {
        let hex = ieee.uppercased().filter(\.isHexDigit)
        guard hex.count >= 6 else { return nil }
        return zigbeeOUIs[String(hex.prefix(6))]
    }

    // MARK: Brands and logos

    /// Common smart-home brands → website (for the logo).
    private static let brandDomains: [(String, String)] = [
        ("philips hue", "philips-hue.com"), ("signify", "philips-hue.com"), ("philips", "philips-hue.com"),
        ("eve", "evehome.com"), ("aqara", "aqara.com"), ("lumi", "aqara.com"), ("ikea", "ikea.com"),
        ("nanoleaf", "nanoleaf.me"), ("meross", "meross.com"), ("tapo", "tapo.com"), ("tp-link", "tp-link.com"),
        ("netatmo", "netatmo.com"), ("ecobee", "ecobee.com"), ("yale", "yalehome.com"), ("nuki", "nuki.io"),
        ("govee", "govee.com"), ("tado", "tado.com"), ("shelly", "shelly.com"), ("eufy", "eufy.com"),
        ("ring", "ring.com"), ("arlo", "arlo.com"), ("logitech", "logitech.com"), ("somfy", "somfy.com"),
        ("elgato", "elgato.com"), ("wemo", "wemo.com"), ("belkin", "belkin.com"), ("lifx", "lifx.com"),
        ("sonos", "sonos.com"), ("google", "store.google.com"), ("nest", "store.google.com"),
        ("amazon", "amazon.com"), ("apple", "apple.com"), ("athom", "homey.app"), ("homey", "homey.app"),
        ("innr", "innr.com"), ("gledopto", "gledopto.com"), ("tuya", "tuya.com"), ("switchbot", "switch-bot.com"),
        ("onvis", "onvistech.com"), ("vocolinc", "vocolinc.com"), ("wiz", "wizconnected.com"), ("ezviz", "ezviz.com"),
        ("bosch", "bosch-smarthome.com"), ("siemens", "siemens.com"), ("legrand", "legrand.com"),
        ("schneider", "se.com"), ("leviton", "leviton.com"), ("lutron", "lutron.com"), ("abode", "goabode.com"),
        ("level", "level.co"), ("aqara", "aqara.com"), ("xiaomi", "mi.com"), ("samsung", "samsung.com"),
        ("smartthings", "smartthings.com"), ("hue", "philips-hue.com"), ("eqiva", "eqiva.com"),
        ("homematic", "homematic-ip.com"), ("fibaro", "fibaro.com"), ("aeotec", "aeotec.com"),
        ("zooz", "getzooz.com"), ("danalock", "danalock.com"), ("velux", "velux.com"), ("dyson", "dyson.com"),
        ("roborock", "roborock.com"), ("ecovacs", "ecovacs.com"), ("irobot", "irobot.com"),
        ("lg", "lg.com"), ("sony", "sony.com"), ("ubiquiti", "ui.com"), ("netgear", "netgear.com"),
        ("avm", "avm.de"), ("fritz", "avm.de"), ("klikaanklikuit", "klikaanklikuit.nl"), ("kaku", "klikaanklikuit.nl"),
        ("calex", "calex.eu"), ("lidl", "lidl.com"), ("silvercrest", "lidl.com"), ("hombli", "hombli.com"),
        ("woox", "wooxhome.com"), ("sengled", "sengled.com"), ("cync", "cync.com"), ("ge lighting", "cync.com"),
    ]

    /// The website of a manufacturer name, when it is a known brand.
    static func domain(forManufacturer name: String) -> String? {
        let n = name.lowercased()
        guard !n.isEmpty else { return nil }
        return brandDomains.first { n == $0.0 || n.hasPrefix($0.0 + " ") || n.contains($0.0) && $0.0.count > 3 }?.1
    }

    /// The brand's own app icon or favicon, as a small PNG.
    static func logo(domain: String) async -> Data? {
        guard isEnabled else { return nil }
        let paths = ["/apple-touch-icon.png", "/apple-touch-icon-precomposed.png", "/favicon.ico", "/favicon.png"]
        for host in [domain, "www." + domain] {
            for path in paths {
                guard let url = URL(string: "https://\(host)\(path)"),
                      let (data, response) = try? await session.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let png = normalizedPNG(data, minSize: 32) else { continue }
                return png
            }
        }
        return nil
    }

    /// Decodes any image format and returns a PNG of at most 180 px, or nil when too small or not an image.
    private static func normalizedPNG(_ data: Data, minSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        // .ico files hold several sizes: take the largest.
        var best = 0, bestSize = 0
        for i in 0..<CGImageSourceGetCount(source) {
            if let p = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let w = p[kCGImagePropertyPixelWidth] as? Int, w > bestSize { best = i; bestSize = w }
        }
        guard bestSize >= minSize else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 180,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, best, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    /// Fetches and stores the logo of a device's brand when it doesn't have one yet.
    @MainActor
    static func fetchLogoIfNeeded(for device: Device) async {
        guard isEnabled, device.logoData == nil else { return }
        let domain = device.logoDomain.isEmpty ? (domain(forManufacturer: device.manufacturer) ?? "") : device.logoDomain
        guard !domain.isEmpty, let png = await logo(domain: domain) else { return }
        device.logoDomain = domain
        device.logoData = png
        try? device.modelContext?.save()
    }
}
