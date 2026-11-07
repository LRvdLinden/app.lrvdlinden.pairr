import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let pairrBackup = UTType(exportedAs: "app.lrvdlinden.pairr.backup", conformingTo: .data)
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf, csv, markdown, backup
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .pdf: "PDF to print"
        case .csv: "CSV (Excel, Numbers)"
        case .markdown: "Markdown"
        case .backup: "Pairr backup with password"
        }
    }

    var symbol: String {
        switch self {
        case .pdf: "doc.richtext"
        case .csv: "tablecells"
        case .markdown: "text.alignleft"
        case .backup: "lock.doc"
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf: "pdf"
        case .csv: "csv"
        case .markdown: "md"
        case .backup: "pairrbackup"
        }
    }
}

@MainActor
enum ExportService {
    static func fileName(_ format: ExportFormat) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "Pairr \(f.string(from: .now)).\(format.fileExtension)"
    }

    /// Writes the export to a temporary file and returns its URL.
    static func export(_ format: ExportFormat, devices: [Device], password: String = "") throws -> URL {
        let data: Data
        switch format {
        case .csv: data = csv(devices)
        case .markdown: data = Data(markdown(devices).utf8)
        case .pdf: data = pdf(devices)
        case .backup: data = try Backup.sealWithPassword(Backup.encode(Backup.snapshot(devices)), password: password)
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PairrExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName(format))
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    // MARK: CSV

    static let csvHeader = ["Name", "Type", "Manufacturer", "Model", "Home", "Room", "Serial number",
                            "Code type", "Label", "Code", "Second value", "QR payload", "Notes"]

    static func csv(_ devices: [Device]) -> Data {
        var rows = [csvHeader]
        for d in devices {
            let base = [d.name, d.kindRaw, d.manufacturer, d.model, d.home, d.room, d.serialNumber]
            let codes = d.sortedCodes
            if codes.isEmpty {
                rows.append(base + ["", "", "", "", "", d.notes])
            }
            for c in codes {
                let s = c.secret
                rows.append(base + [c.typeRaw, c.label, s.map { CodeParser.format(c.type, $0.value) } ?? "",
                                    s?.secondary ?? "", s?.qrPayload ?? "", d.notes])
            }
        }
        let text = rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n")
        return Data(("\u{FEFF}" + text).utf8)
    }

    private static func escape(_ s: String) -> String {
        s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
            ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            : s
    }

    // MARK: Markdown

    static func markdown(_ devices: [Device]) -> String {
        var out = "# Pairr\n\n"
        let grouped = Dictionary(grouping: devices) { $0.room.isEmpty ? String(localized: "No room") : $0.room }
        for room in grouped.keys.sorted() {
            out += "## \(room)\n\n"
            for d in grouped[room] ?? [] {
                out += "### \(d.displayName)\n\n"
                if !d.subtitle.isEmpty { out += "\(d.subtitle)\n\n" }
                for c in d.sortedCodes {
                    guard let s = c.secret else { continue }
                    out += "- **\(c.title)**: `\(CodeParser.format(c.type, s.value))`"
                    if !s.secondary.isEmpty { out += " · \(c.type.secondaryLabel ?? ""): `\(s.secondary)`" }
                    out += "\n"
                }
                if !d.serialNumber.isEmpty { out += "- \(String(localized: "Serial number")): \(d.serialNumber)\n" }
                if !d.stickerLocation.isEmpty { out += "- \(String(localized: "Original sticker")): \(d.stickerLocation)\n" }
                if !d.notes.isEmpty { out += "\n\(d.notes)\n" }
                out += "\n"
            }
        }
        return out
    }

    // MARK: PDF

    static func pdf(_ devices: [Device]) -> Data {
        let pageSize = CGSize(width: 595, height: 842)   // A4
        let perPage = 5
        let chunks = stride(from: 0, to: max(devices.count, 1), by: perPage).map {
            Array(devices[$0..<min($0 + perPage, devices.count)])
        }
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        for (index, chunk) in chunks.enumerated() {
            let page = PDFPageView(devices: chunk, page: index + 1, pages: chunks.count)
                .frame(width: pageSize.width, height: pageSize.height)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: page)
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, draw in
                ctx.beginPDFPage(nil)
                draw(ctx)
                ctx.endPDFPage()
            }
        }
        ctx.closePDF()
        return data as Data
    }
}

/// One A4 page of the printable overview.
private struct PDFPageView: View {
    let devices: [Device]
    let page: Int
    let pages: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PairrLogo(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pairr").font(.system(size: 18, weight: .bold))
                    Text("My pairing codes").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Date.now, style: .date).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Divider()
            ForEach(devices) { d in
                deviceBlock(d)
                Divider()
            }
            Spacer(minLength: 0)
            HStack {
                Text("Keep this page in a safe place: it contains your codes.")
                Spacer()
                Text(verbatim: "\(page) / \(pages)")
            }
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
        }
        .padding(36)
        .background(Color.white)
        .foregroundStyle(Color.black)
    }

    private func deviceBlock(_ d: Device) -> some View {
        HStack(alignment: .top, spacing: 12) {
            DeviceIcon(kind: d.kind, color: d.color, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: d.displayName).font(.system(size: 13, weight: .semibold))
                let info = [d.subtitle, d.serialNumber.isEmpty ? "" : "S/N \(d.serialNumber)"].filter { !$0.isEmpty }
                if !info.isEmpty {
                    Text(verbatim: info.joined(separator: " · ")).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                ForEach(d.sortedCodes) { c in
                    if let s = c.secret {
                        HStack(spacing: 6) {
                            Text(verbatim: c.title).font(.system(size: 9, weight: .medium)).foregroundStyle(c.type.color)
                            Text(verbatim: CodeParser.format(c.type, s.value)).font(.system(size: 11, weight: .semibold, design: .monospaced))
                            if !s.secondary.isEmpty {
                                Text(verbatim: s.secondary).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                ForEach(d.sortedCodes.prefix(2)) { c in
                    if let s = c.secret {
                        if let p = s.qrPayload, let img = QRCode.image(p) {
                            img.resizable().interpolation(.none).frame(width: 74, height: 74)
                        } else if c.type == .homeKit {
                            HomeKitLabel(code: s.value, width: 110)
                        }
                    }
                }
            }
        }
    }
}

// MARK: CSV import

enum CSVImport {
    /// Reads a CSV (Pairr, HomePass or a hand-made sheet) and adds the devices with their codes.
    @MainActor
    static func run(_ data: Data, into context: ModelContext) throws -> Int {
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return 0 }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let separator: Character = text.prefix(2000).filter { $0 == ";" }.count > text.prefix(2000).filter { $0 == "," }.count ? ";" : ","
        let rows = parse(text, separator: separator)
        guard let header = rows.first?.map({ $0.lowercased().trimmed }), rows.count > 1 else { return 0 }

        func col(_ names: [String]) -> Int? { header.firstIndex { h in names.contains { h.contains($0) } } }
        let iName = col(["name", "naam", "accessory", "device", "apparaat"])
        let iMan = col(["manufacturer", "fabrikant", "brand", "merk"])
        let iModel = col(["model"])
        let iHome = col(["home", "woning", "huis"])
        let iRoom = col(["room", "kamer", "ruimte"])
        let iSerial = col(["serial", "serie"])
        let iCodeType = col(["code type", "codetype"])
        let iCode = header.firstIndex { $0 == "code" } ?? col(["setup code", "homekit code", "matter code", "pairing code", "setupcode", "koppelcode"])
        let iSecond = col(["second value", "ieee", "mac"])
        let iQR = col(["qr"])
        let iNotes = col(["notes", "notitie", "note"])

        var byName: [String: Device] = [:]
        var count = 0
        for row in rows.dropFirst() where row.contains(where: { !$0.trimmed.isEmpty }) {
            func v(_ i: Int?) -> String { i.flatMap { $0 < row.count ? row[$0].trimmed : nil } ?? "" }
            let name = v(iName).isEmpty ? String(localized: "Imported device") : v(iName)
            let key = name + "|" + v(iRoom)
            let d: Device
            if let existing = byName[key] {
                d = existing
            } else {
                d = Device(name: name)
                d.manufacturer = v(iMan); d.model = v(iModel); d.home = v(iHome); d.room = v(iRoom)
                d.serialNumber = v(iSerial); d.notes = v(iNotes)
                context.insert(d)
                byName[key] = d
                count += 1
            }
            let raw = v(iCode)
            guard !raw.isEmpty || !v(iQR).isEmpty else { continue }
            let typeHint = CodeType(rawValue: v(iCodeType)) ?? CodeType.allCases.first { $0.title.lowercased() == v(iCodeType).lowercased() }
            let parsed = (v(iQR).isEmpty ? nil : CodeParser.detect(v(iQR)))
                ?? CodeParser.detect(raw, preferred: typeHint)
                ?? ParsedCode(type: typeHint ?? .other, value: raw)
            let code = PairingCode(type: parsed.type)
            var secret = CodeSecret(value: CodeParser.normalize(parsed.type, parsed.value),
                                    secondary: v(iSecond).isEmpty ? parsed.secondary : v(iSecond),
                                    qrPayload: parsed.qrPayload)
            if let p = parsed.qrPayload { secret.qrPNG = QRCode.pngData(p) }
            try code.setSecret(secret)
            context.insert(code)
            d.codes = (d.codes ?? []) + [code]
            if let k = parsed.suggestedKind, d.kind == .other { d.kind = k }
        }
        try context.save()
        return count
    }

    static func parse(_ text: String, separator: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == separator {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field); field = ""
                rows.append(row); row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}
