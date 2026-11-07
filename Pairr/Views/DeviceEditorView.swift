import SwiftUI
import SwiftData

/// Creates a device (optionally with a just-scanned code) or edits one.
struct DeviceEditorView: View {
    let device: Device?
    let initialCode: ParsedCode?
    var onCreated: (Device) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Device.name) private var all: [Device]

    @State private var name = ""
    @State private var kind: DeviceKind = .other
    @State private var colorHex = Theme.swatches[0]
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var serial = ""
    @State private var firmware = ""
    @State private var home = ""
    @State private var room = ""
    @State private var isBridged = false
    @State private var hasPurchase = false
    @State private var purchaseDate = Date()
    @State private var store = ""
    @State private var hasWarranty = false
    @State private var warrantyUntil = Calendar.current.date(byAdding: .year, value: 2, to: .now) ?? .now
    @State private var sticker = ""
    @State private var notes = ""
    @State private var fields: [EditableField] = []
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var saved = 0
    @State private var lookingUp = false
    @State private var info: DeviceInfo?
    @State private var logoData: Data?
    @State private var originalManufacturer: String?

    struct EditableField: Identifiable {
        var id = UUID()
        var key: String
        var value: String
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        if let logoData, let logo = Image(imageData: logoData) {
                            logo.resizable().scaledToFit()
                                .padding(8)
                                .frame(width: 54, height: 54)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(alignment: .bottomTrailing) {
                                    DeviceIcon(kind: kind, color: Color(hex: colorHex) ?? Theme.accent, size: 22)
                                        .offset(x: 5, y: 5)
                                }
                        } else {
                            DeviceIcon(kind: kind, color: Color(hex: colorHex) ?? Theme.accent, size: 54)
                        }
                        TextField("Name", text: $name, prompt: Text("For example: Hue bulb hallway"))
                            .font(.title3)
                    }
                    if let initialCode {
                        HStack {
                            CodeTypeBadge(type: initialCode.type)
                            Text(verbatim: CodeParser.format(initialCode.type, initialCode.value))
                                .font(.body.monospaced())
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
                        }
                    }
                    if lookingUp {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking up product details…").foregroundStyle(.secondary)
                        }
                    } else if let info, !info.source.isEmpty {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Filled in automatically")
                                Text(verbatim: info.source).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                        }
                    }
                }

                Section("Type of device") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
                        ForEach(DeviceKind.allCases) { k in
                            Button { kind = k } label: {
                                Image(systemName: k.symbol)
                                    .font(.title3)
                                    .frame(width: 48, height: 48)
                                    .foregroundStyle(kind == k ? .white : .primary)
                                    .background(kind == k ? (Color(hex: colorHex) ?? Theme.accent) : Color.secondary.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: k.title))
                            .accessibilityAddTraits(kind == k ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    Text(verbatim: kind.title).font(.footnote).foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(Theme.swatches, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.primary.opacity(colorHex == hex ? 0.9 : 0), lineWidth: 2.5).padding(-4))
                                .onTapGesture { colorHex = hex }
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Where") {
                    suggestField("Home", text: $home, values: all.map(\.home))
                    suggestField("Room", text: $room, values: all.map(\.room))
                    TextField("Where is the original sticker?", text: $sticker, prompt: Text("For example: in the box in the meter cupboard"))
                }

                Section("Device") {
                    suggestField("Manufacturer", text: $manufacturer, values: all.map(\.manufacturer))
                    TextField("Model", text: $model)
                    TextField("Serial number", text: $serial).font(.body.monospaced())
                    TextField("Firmware", text: $firmware)
                    Toggle("Connected through a bridge", isOn: $isBridged)
                }

                Section("Purchase") {
                    Toggle("Purchase date", isOn: $hasPurchase.animation())
                    if hasPurchase { DatePicker("Date", selection: $purchaseDate, displayedComponents: .date) }
                    TextField("Bought at", text: $store)
                    Toggle("Warranty", isOn: $hasWarranty.animation())
                    if hasWarranty { DatePicker("Warranty until", selection: $warrantyUntil, displayedComponents: .date) }
                }

                Section {
                    ForEach($fields) { $field in
                        HStack {
                            TextField("Field", text: $field.key)
                                .frame(maxWidth: 140)
                            Divider()
                            TextField("Value", text: $field.value)
                        }
                    }
                    .onDelete { fields.remove(atOffsets: $0) }
                    Button { fields.append(EditableField(key: "", value: "")) } label: {
                        Label("Add field", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Custom fields")
                } footer: {
                    Text("For example the IP address, MAC address or the hub it's paired with.")
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                if device != nil {
                    Section {
                        Button("Delete device", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(device == nil ? LocalizedStringKey("New device") : LocalizedStringKey("Edit device"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmed.isEmpty)
                }
            }
            .confirmationDialog("Delete this device?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteDevice() }
            } message: {
                Text("Its codes and attachments are deleted on all your devices.")
            }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear(perform: load)
            .task { await lookUp() }
        }
        .modalTracked()
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    /// A text field with a menu of values used before.
    private func suggestField(_ title: LocalizedStringKey, text: Binding<String>, values: [String]) -> some View {
        let options = Array(Set(values.filter { !$0.isEmpty })).sorted()
        return HStack {
            TextField(title, text: text)
            if !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { v in Button(v) { text.wrappedValue = v } }
                } label: {
                    Image(systemName: "chevron.down.circle")
                }
                .buttonStyle(.borderless)
                .fixedSize()
                .accessibilityLabel(Text("Choose"))
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let d = device {
            originalManufacturer = d.manufacturer
            name = d.name; kind = d.kind; colorHex = d.colorHex
            manufacturer = d.manufacturer; model = d.model; serial = d.serialNumber; firmware = d.firmware
            home = d.home; room = d.room; isBridged = d.isBridged
            if let p = d.purchaseDate { hasPurchase = true; purchaseDate = p }
            store = d.store
            if let w = d.warrantyUntil { hasWarranty = true; warrantyUntil = w }
            sticker = d.stickerLocation; notes = d.notes
            fields = d.sortedFields.map { EditableField(key: $0.key, value: $0.value) }
        } else if let initialCode {
            if let k = initialCode.suggestedKind { kind = k }
            name = initialCode.type == .hue ? "Philips Hue" : ""
            if initialCode.type == .hue { manufacturer = "Signify"; kind = .light }
        }
        // Use the last home when there is only one.
        if device == nil, home.isEmpty {
            let homes = Set(all.map(\.home).filter { !$0.isEmpty })
            if homes.count == 1 { home = homes.first ?? "" }
        }
    }

    /// Fills empty fields from the Matter register, the Zigbee address or the Hue code, and loads the brand logo.
    private func lookUp() async {
        guard device == nil, let code = initialCode, info == nil else { return }
        lookingUp = true
        let found = await DeviceLookup.info(for: code)
        lookingUp = false
        guard let found else { return }
        info = found
        withAnimation {
            if name.trimmed.isEmpty || name == "Philips Hue" {
                name = found.productName.isEmpty ? found.manufacturer : found.productName
            }
            if manufacturer.trimmed.isEmpty { manufacturer = found.manufacturer }
            if model.trimmed.isEmpty { model = found.model }
            if let k = found.kind, kind == .other || initialCode?.suggestedKind == nil { kind = k }
        }
        if let domain = found.brandDomain ?? DeviceLookup.domain(forManufacturer: found.manufacturer),
           let png = await DeviceLookup.logo(domain: domain) {
            withAnimation { logoData = png }
        }
    }

    private func save() {
        let d = device ?? Device()
        d.name = name.trimmed
        d.kind = kind
        d.colorHex = colorHex
        d.manufacturer = manufacturer.trimmed
        d.model = model.trimmed
        d.serialNumber = serial.trimmed
        d.firmware = firmware.trimmed
        d.home = home.trimmed
        d.room = room.trimmed
        d.isBridged = isBridged
        d.purchaseDate = hasPurchase ? purchaseDate : nil
        d.store = store.trimmed
        d.warrantyUntil = hasWarranty ? warrantyUntil : nil
        d.stickerLocation = sticker.trimmed
        d.notes = notes.trimmed
        d.touch()
        if device == nil { context.insert(d) }

        // Custom fields: replace.
        for f in d.customFields ?? [] { context.delete(f) }
        d.customFields = []
        for (i, f) in fields.enumerated() where !f.key.trimmed.isEmpty || !f.value.trimmed.isEmpty {
            let field = CustomField(key: f.key.trimmed, value: f.value.trimmed, order: i)
            context.insert(field)
            d.customFields?.append(field)
        }

        if device == nil, let p = initialCode {
            let code = PairingCode(type: p.type)
            var secret = CodeSecret(value: CodeParser.normalize(p.type, p.value), secondary: p.secondary, qrPayload: p.qrPayload)
            if let payload = p.qrPayload { secret.qrPNG = QRCode.pngData(payload) }
            if (try? code.setSecret(secret)) != nil {
                context.insert(code)
                d.codes = (d.codes ?? []) + [code]
            }
            #if os(iOS)
            KeySync.shared.pushKey()
            #endif
        }
        if device == nil, let info {
            for (url, title) in [(info.productURL, String(localized: "Product page")),
                                 (info.manualURL, String(localized: "Manual")),
                                 (info.supportURL, String(localized: "Support"))] {
                guard let url else { continue }
                let link = Attachment(kind: .link, name: title)
                link.urlString = url.absoluteString
                context.insert(link)
                d.attachments = (d.attachments ?? []) + [link]
            }
            if let domain = info.brandDomain { d.logoDomain = domain }
        }
        if let logoData { d.logoData = logoData }
        try? context.save()
        saved += 1
        if device == nil { onCreated(d) }
        if d.logoData == nil || manufacturerChanged(d) {
            if manufacturerChanged(d) { d.logoData = nil; d.logoDomain = "" }
            Task { await DeviceLookup.fetchLogoIfNeeded(for: d) }
        }
        dismiss()
    }

    /// True when the manufacturer was edited, so the old logo no longer fits.
    private func manufacturerChanged(_ d: Device) -> Bool {
        guard let original = originalManufacturer else { return false }
        return original.lowercased() != d.manufacturer.lowercased() && logoData == nil
    }

    private func deleteDevice() {
        guard let device else { return }
        context.delete(device)
        try? context.save()
        dismiss()
        onDeleted()
    }
}
