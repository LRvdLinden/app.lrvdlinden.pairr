import SwiftUI
import SwiftData

struct DeviceDetailView: View {
    @Bindable var device: Device
    var onDeleted: () -> Void = {}

    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var addingCode = false
    @State private var editingCode: PairingCode?
    @State private var showingCode: PairingCode?
    @State private var deletingCode: PairingCode?

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            Section {
                ForEach(device.sortedCodes) { code in
                    CodeRow(code: code,
                            onShow: { showingCode = code },
                            onEdit: { editingCode = code },
                            onDelete: { deletingCode = code })
                }
                Button { addingCode = true } label: {
                    Label("Add code", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Codes")
            } footer: {
                if (device.codes ?? []).isEmpty {
                    Text("Add the HomeKit, Matter, Zigbee, Hue or Z-Wave code of this device.")
                }
            }

            DeviceInfoSection(device: device)

            if !device.sortedFields.isEmpty {
                Section("Custom fields") {
                    ForEach(device.sortedFields) { f in
                        LabeledContent { Text(verbatim: f.value).textSelection(.enabled) } label: { Text(verbatim: f.key) }
                    }
                }
            }

            AttachmentsSection(device: device)

            if !device.notes.isEmpty {
                Section("Notes") {
                    Text(verbatim: device.notes).textSelection(.enabled)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(device.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    device.isFavorite.toggle()
                    device.touch()
                } label: {
                    Label("Favorite", systemImage: device.isFavorite ? "star.fill" : "star")
                }
                .sensoryFeedback(.selection, trigger: device.isFavorite)
                Button("Edit") { editing = true }
            }
        }
        .task(id: device.manufacturer) { await DeviceLookup.fetchLogoIfNeeded(for: device) }
        .sheet(isPresented: $editing) {
            DeviceEditorView(device: device, initialCode: nil, onDeleted: onDeleted)
        }
        .sheet(isPresented: $addingCode) {
            CodeEditorView(device: device, existing: nil, initial: nil)
        }
        .sheet(item: $editingCode) { code in
            CodeEditorView(device: device, existing: code, initial: nil)
        }
        .sheet(item: $showingCode) { code in
            CodeDisplayView(code: code, deviceName: device.displayName)
        }
        .confirmationDialog("Delete this code?", isPresented: Binding(get: { deletingCode != nil },
                                                                     set: { if !$0 { deletingCode = nil } }),
                            titleVisibility: .visible, presenting: deletingCode) { code in
            Button("Delete", role: .destructive) {
                context.delete(code)
                device.touch()
                try? context.save()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            DeviceAvatar(device: device, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: device.displayName)
                    .font(.title2.bold())
                Text(verbatim: device.kind.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !device.home.isEmpty || !device.room.isEmpty {
                    Label {
                        Text(verbatim: [device.home, device.room].filter { !$0.isEmpty }.joined(separator: " · "))
                    } icon: {
                        Image(systemName: "house")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

/// Manufacturer, model, serial number, dates…
private struct DeviceInfoSection: View {
    let device: Device

    var body: some View {
        let allRows: [(LocalizedStringKey, String)] = [
            ("Manufacturer", device.manufacturer),
            ("Model", device.model),
            ("Serial number", device.serialNumber),
            ("Firmware", device.firmware),
            ("Original sticker", device.stickerLocation),
            ("Bought at", device.store),
        ]
        let rows = allRows.filter { !$0.1.isEmpty }
        if !rows.isEmpty || device.purchaseDate != nil || device.warrantyUntil != nil || device.isBridged {
            Section("Details") {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent {
                        Text(verbatim: row.1).textSelection(.enabled)
                    } label: {
                        Text(row.0)
                    }
                }
                if let d = device.purchaseDate {
                    LabeledContent("Purchase date") { Text(d, style: .date) }
                }
                if let w = device.warrantyUntil {
                    LabeledContent("Warranty until") {
                        Text(w, style: .date).foregroundStyle(w < .now ? .red : .primary)
                    }
                }
                if device.isBridged {
                    LabeledContent("Connection") { Text("Through a bridge") }
                }
            }
        }
    }
}

/// One code: type, value (hidden until tapped), copy and QR.
struct CodeRow: View {
    let code: PairingCode
    var onShow: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @AppStorage("security.revealCodes") private var revealAll = false
    @State private var revealed = false
    @State private var copied = 0

    var body: some View {
        let secret = code.secret
        HStack(alignment: .center, spacing: 12) {
            CodeTypeBadge(type: code.type, compact: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: code.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let secret {
                    let visible = revealed || revealAll
                    Text(verbatim: visible ? CodeParser.format(code.type, secret.value) : masked(secret.value))
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .textSelection(.enabled)
                        .contentTransition(.opacity)
                    if !secret.secondary.isEmpty, let label = code.type.secondaryLabel {
                        Text(verbatim: "\(label): " + (visible ? secondaryText(secret.secondary) : "••••••"))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("This code can't be decrypted on this device.", systemImage: "exclamationmark.lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 4)
            if let secret {
                Button {
                    Clipboard.copy(CodeParser.format(code.type, secret.value))
                    copied += 1
                } label: {
                    Label("Copy", systemImage: "doc.on.doc").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .sensoryFeedback(.success, trigger: copied)
                Button(action: onShow) {
                    Label("Show code", systemImage: secret.qrPayload != nil ? "qrcode" : "rectangle.expand.vertical")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { revealed.toggle() } }
        .contextMenu {
            Button(action: onShow) { Label("Show code", systemImage: "qrcode") }
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
        .swipeActions {
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
        }
        .accessibilityAction(named: Text("Show code"), onShow)
    }

    private func masked(_ value: String) -> String {
        let shown = CodeParser.format(code.type, value)
        return String(shown.map { $0.isLetter || $0.isNumber ? "•" : $0 })
    }

    private func secondaryText(_ s: String) -> String {
        code.type == .zigbee ? CodeParser.formatIEEE(s) : (code.type == .hue ? CodeParser.format(.homeKit, s) : s)
    }
}
