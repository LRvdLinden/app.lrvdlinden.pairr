import Foundation

/// A pairing code recognised in a QR code, NFC tag, photo or typed text.
struct ParsedCode: Hashable, Identifiable {
    var type: CodeType
    var value: String
    var secondary: String = ""
    /// The full QR/NFC payload, kept so Pairr can show the same QR code again.
    var qrPayload: String? = nil
    var homeKitCategory: Int? = nil
    var vendorID: Int? = nil
    var productID: Int? = nil

    var id: String { type.rawValue + "|" + value + "|" + secondary }
    var suggestedKind: DeviceKind? { homeKitCategory.flatMap { DeviceKind(homeKitCategory: $0) } }
}

enum CodeValidation: Equatable {
    case valid
    case warning(String)
    case unknown
}

/// Recognises, checks and formats HomeKit, Matter, Zigbee, Hue and Z-Wave codes.
enum CodeParser {

    // MARK: Detect

    /// Recognises one scanned or typed string. `preferred` helps with ambiguous input.
    static func detect(_ raw: String, preferred: CodeType? = nil) -> ParsedCode? {
        let s = raw.trimmed
        guard !s.isEmpty else { return nil }
        let up = s.uppercased()

        if let r = up.range(of: "X-HM://") { return parseHomeKitPayload(String(up[r.upperBound...])) }
        if let r = up.range(of: "MT:") { return parseMatterPayload(String(up[r.lowerBound...])) }
        if let z = parseZigbeePayload(up) { return z }

        let digits = s.filter(\.isASCIIDigit)
        let others = s.filter { !$0.isASCIIDigit && !" -\u{2013}.".contains($0) }
        if others.isEmpty, !digits.isEmpty {
            if digits.hasPrefix("90"), digits.count >= 52 {
                let dsk = String(Array(digits)[12..<52])
                return ParsedCode(type: .zwave, value: dsk, qrPayload: digits)
            }
            if digits.count == 8, preferred == nil || preferred == .homeKit {
                return ParsedCode(type: .homeKit, value: digits)
            }
            if digits.count == 11 || digits.count == 21, verhoeffValid(digits) {
                return ParsedCode(type: .matter, value: digits)
            }
            if digits.count == 40 {
                return ParsedCode(type: .zwave, value: digits)
            }
        }

        let hex = up.filter { !" -:".contains($0) }
        if !hex.isEmpty, hex.allSatisfy(\.isHexDigit) {
            if hex.count == 6, preferred == .hue || preferred == nil, !hex.allSatisfy(\.isASCIIDigit) {
                return ParsedCode(type: .hue, value: hex)
            }
            if [16, 20, 28, 36].contains(hex.count), preferred == .zigbee || zigbeeInstallCodeValid(hex) {
                return ParsedCode(type: .zigbee, value: hex)
            }
        }

        if let preferred { return ParsedCode(type: preferred, value: s) }
        return nil
    }

    /// Finds codes in free text, such as the text Vision reads from a photo of a sticker.
    static func candidates(inText text: String, preferred: CodeType? = nil) -> [ParsedCode] {
        var found: [ParsedCode] = []
        func add(_ p: ParsedCode?) {
            guard let p, !found.contains(where: { $0.type == p.type && $0.value == p.value }) else { return }
            found.append(p)
        }
        let up = text.uppercased()
        let patterns: [(String, CodeType?)] = [
            (#"X-HM://[0-9A-Z]{9,13}"#, nil),
            (#"MT:[0-9A-Z.\-]{19,}"#, nil),
            (#"(?<![0-9])\d{4}[ \-]?\d{3}[ \-]?\d{4}(?:[ \-]?\d{5}[ \-]?\d{5})?(?![0-9])"#, .matter),
            (#"(?<![0-9])\d{3}[ \-]?\d{2}[ \-]?\d{3}(?![0-9])"#, .homeKit),
            (#"(?<![0-9])\d{4}[ \-]?\d{4}(?![0-9])"#, .homeKit),
            (#"(?<![0-9])(?:\d{5}[ \-]?){7}\d{5}(?![0-9])"#, .zwave),
            (#"(?<![0-9A-F])[0-9A-F]{4}(?:[ \-]?[0-9A-F]{4}){3,8}(?![0-9A-F])"#, .zigbee),
        ]
        for (pattern, type) in patterns {
            for match in matches(pattern, in: up) {
                if let type, type == .homeKit, preferred != nil, preferred != .homeKit { continue }
                if type == .zigbee, preferred != .zigbee, !zigbeeInstallCodeValid(match.filter(\.isHexDigit)) { continue }
                add(detect(match, preferred: type))
            }
        }
        if preferred == .hue || found.isEmpty {
            for match in matches(#"(?<![0-9A-Z])[0-9A-F]{6}(?![0-9A-Z])"#, in: up) where !match.allSatisfy(\.isASCIIDigit) {
                add(ParsedCode(type: .hue, value: match))
            }
        }
        // An IEEE address next to a Zigbee install code belongs to it.
        if let ieee = matches(#"(?<![0-9A-F])(?:[0-9A-F]{2}[:\- ]?){7}[0-9A-F]{2}(?![0-9A-F])"#, in: up).first,
           let i = found.firstIndex(where: { $0.type == .zigbee && $0.secondary.isEmpty }) {
            let clean = ieee.filter(\.isHexDigit)
            if clean != found[i].value { found[i].secondary = clean }
        }
        return found
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    // MARK: HomeKit

    /// X-HM:// payload: 9 base-36 characters (setup code, flags, category) + 4-character setup ID.
    static func parseHomeKitPayload(_ rest: String) -> ParsedCode? {
        let chars = Array(rest.filter { $0.isLetter || $0.isNumber })
        guard chars.count >= 9, let v = UInt64(String(chars[0..<9]), radix: 36) else { return nil }
        let code = Int(v & 0x7FF_FFFF)
        let category = Int((v >> 31) & 0xFF)
        guard code <= 99_999_999 else { return nil }
        return ParsedCode(type: .homeKit,
                          value: String(format: "%08d", code),
                          qrPayload: "X-HM://" + String(chars.prefix(13)),
                          homeKitCategory: category)
    }

    /// HomeKit forbids a few trivial codes.
    static let invalidHomeKitCodes: Set<String> = [
        "00000000", "11111111", "22222222", "33333333", "44444444", "55555555",
        "66666666", "77777777", "88888888", "99999999", "12345678", "87654321",
    ]

    // MARK: Matter

    private static let base38 = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-.")

    static func base38Decode(_ s: String) -> [UInt8]? {
        let chars = Array(s)
        var out: [UInt8] = []
        var i = 0
        while i < chars.count {
            let remaining = chars.count - i
            let chunk = remaining >= 5 ? 5 : (remaining == 4 ? 4 : (remaining == 2 ? 2 : 0))
            guard chunk > 0 else { return nil }
            var value: UInt32 = 0
            for j in stride(from: chunk - 1, through: 0, by: -1) {
                guard let idx = base38.firstIndex(of: chars[i + j]) else { return nil }
                value = value * 38 + UInt32(idx)
            }
            let bytes = chunk == 5 ? 3 : (chunk == 4 ? 2 : 1)
            for b in 0..<bytes { out.append(UInt8((value >> (8 * UInt32(b))) & 0xFF)) }
            i += chunk
        }
        return out
    }

    private static func readBits(_ bytes: [UInt8], _ offset: inout Int, _ count: Int) -> Int {
        var v = 0
        for k in 0..<count {
            let bit = offset + k
            guard bit / 8 < bytes.count else { break }
            if (bytes[bit / 8] >> UInt8(bit % 8)) & 1 == 1 { v |= 1 << k }
        }
        offset += count
        return v
    }

    /// MT: payload → vendor, product, discriminator and passcode → 11-digit manual code.
    static func parseMatterPayload(_ payload: String) -> ParsedCode? {
        var body = payload.uppercased()
        if body.hasPrefix("MT:") { body.removeFirst(3) }
        body = String(body.prefix { $0 != "*" && !$0.isWhitespace })
        guard let bytes = base38Decode(body), bytes.count >= 11 else { return nil }
        var o = 0
        _ = readBits(bytes, &o, 3)                 // version
        let vendor = readBits(bytes, &o, 16)
        let product = readBits(bytes, &o, 16)
        _ = readBits(bytes, &o, 2)                 // commissioning flow
        _ = readBits(bytes, &o, 8)                 // discovery capabilities
        let discriminator = readBits(bytes, &o, 12)
        let passcode = readBits(bytes, &o, 27)
        guard passcode > 0, passcode < 99_999_999 else { return nil }
        return ParsedCode(type: .matter,
                          value: matterManualCode(discriminator: discriminator, passcode: passcode),
                          qrPayload: "MT:" + body,
                          vendorID: vendor, productID: product)
    }

    static func matterManualCode(discriminator: Int, passcode: Int) -> String {
        let short = discriminator >> 8
        let c1 = (short >> 2) & 0x3
        let c2 = ((short & 0x3) << 14) | (passcode & 0x3FFF)
        let c3 = passcode >> 14
        let base = "\(c1)" + String(format: "%05d", c2) + String(format: "%04d", c3)
        return base + String(verhoeffCheckDigit(base))
    }

    private static let vd: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
        [2, 3, 4, 0, 1, 7, 8, 9, 5, 6], [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
        [4, 0, 1, 2, 3, 9, 5, 6, 7, 8], [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
        [6, 5, 9, 8, 7, 1, 0, 4, 3, 2], [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
        [8, 7, 6, 5, 9, 3, 2, 1, 0, 4], [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ]
    private static let vp: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
        [5, 8, 0, 3, 7, 9, 6, 1, 4, 2], [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
        [9, 4, 5, 3, 1, 2, 6, 8, 7, 0], [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
        [2, 7, 9, 3, 8, 0, 6, 4, 1, 5], [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ]
    private static let vinv = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9]

    static func verhoeffCheckDigit(_ digits: String) -> Int {
        var c = 0
        for (i, ch) in digits.reversed().enumerated() {
            c = vd[c][vp[(i + 1) % 8][ch.wholeNumberValue ?? 0]]
        }
        return vinv[c]
    }

    static func verhoeffValid(_ digits: String) -> Bool {
        var c = 0
        for (i, ch) in digits.reversed().enumerated() {
            c = vd[c][vp[i % 8][ch.wholeNumberValue ?? 0]]
        }
        return c == 0
    }

    // MARK: Zigbee

    /// Zigbee 3.0 QR codes in the common "Z:<IEEE>$I:<install code>" form.
    static func parseZigbeePayload(_ up: String) -> ParsedCode? {
        guard up.contains("Z:") || up.contains("$I:") else { return nil }
        let ieee = matches(#"Z:([0-9A-F]{16})"#, in: up).first.map { String($0.dropFirst(2)) } ?? ""
        let install = matches(#"\$I:([0-9A-F]{16,36})"#, in: up).first.map { String($0.dropFirst(3)) } ?? ""
        guard !install.isEmpty || !ieee.isEmpty else { return nil }
        return ParsedCode(type: .zigbee, value: install, secondary: ieee, qrPayload: up)
    }

    static func hexBytes(_ hex: String) -> [UInt8]? {
        let clean = Array(hex.filter(\.isHexDigit))
        guard clean.count % 2 == 0 else { return nil }
        return stride(from: 0, to: clean.count, by: 2).compactMap { UInt8(String(clean[$0..<$0 + 2]), radix: 16) }
    }

    /// CRC-16/X-25 over the install code, stored little-endian in the last two bytes.
    static func zigbeeInstallCodeValid(_ hex: String) -> Bool {
        guard let bytes = hexBytes(hex), [8, 10, 14, 18].contains(bytes.count) else { return false }
        let payload = Array(bytes.dropLast(2))
        let expected = UInt16(bytes[bytes.count - 1]) << 8 | UInt16(bytes[bytes.count - 2])
        return crc16X25(payload) == expected
    }

    static func crc16X25(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for b in bytes {
            crc ^= UInt16(b)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0x8408 : crc >> 1 }
        }
        return ~crc
    }

    // MARK: Normalise, validate, format

    /// The form Pairr stores.
    static func normalize(_ type: CodeType, _ value: String) -> String {
        let v = value.trimmed
        switch type {
        case .homeKit, .matter, .zwave: return v.filter(\.isASCIIDigit)
        case .zigbee, .hue: return v.uppercased().filter(\.isHexDigit)
        case .wifi, .pin, .other: return v
        }
    }

    static func validate(_ type: CodeType, _ value: String, secondary: String = "") -> CodeValidation {
        let v = normalize(type, value)
        guard !v.isEmpty else { return .unknown }
        switch type {
        case .homeKit:
            if v.count != 8 { return .warning(String(localized: "A HomeKit code has 8 digits.")) }
            if invalidHomeKitCodes.contains(v) { return .warning(String(localized: "HomeKit doesn't allow this code. Check it again.")) }
            return .valid
        case .matter:
            guard v.count == 11 || v.count == 21 else { return .warning(String(localized: "A Matter code has 11 or 21 digits.")) }
            return verhoeffValid(v) ? .valid : .warning(String(localized: "The check digit doesn't match. Check the code again."))
        case .zigbee:
            if !zigbeeInstallCodeValid(v) { return .warning(String(localized: "The checksum of this install code doesn't match. Check it again.")) }
            let ieee = secondary.filter(\.isHexDigit)
            if !ieee.isEmpty, ieee.count != 16 { return .warning(String(localized: "An IEEE address has 16 characters.")) }
            return .valid
        case .hue:
            return v.count == 6 ? .valid : .warning(String(localized: "A Hue serial number has 6 characters."))
        case .zwave:
            return v.count == 40 ? .valid : .warning(String(localized: "A Z-Wave DSK has 40 digits."))
        case .wifi, .pin, .other:
            return .valid
        }
    }

    /// How a code is shown: 123-45-678, 3497-011-2332, groups of 4 or 5.
    static func format(_ type: CodeType, _ value: String) -> String {
        let v = normalize(type, value)
        switch type {
        case .homeKit where v.count == 8:
            return group(v, [3, 2, 3], "-")
        case .matter where v.count == 11:
            return group(v, [4, 3, 4], "-")
        case .matter where v.count == 21:
            return group(v, [4, 3, 4, 5, 5], "-")
        case .zigbee:
            return group(v, Array(repeating: 4, count: (v.count + 3) / 4), " ")
        case .zwave:
            return group(v, Array(repeating: 5, count: (v.count + 4) / 5), "-")
        default:
            return v
        }
    }

    /// An IEEE address as 00:17:88:…
    static func formatIEEE(_ value: String) -> String {
        let v = value.uppercased().filter(\.isHexDigit)
        guard v.count == 16 else { return value }
        return group(v, Array(repeating: 2, count: 8), ":")
    }

    private static func group(_ s: String, _ sizes: [Int], _ sep: String) -> String {
        var parts: [String] = []
        var rest = Substring(s)
        for size in sizes where !rest.isEmpty {
            parts.append(String(rest.prefix(size)))
            rest = rest.dropFirst(size)
        }
        if !rest.isEmpty { parts.append(String(rest)) }
        return parts.joined(separator: sep)
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
