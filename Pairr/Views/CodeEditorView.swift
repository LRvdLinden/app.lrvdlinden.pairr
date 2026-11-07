import SwiftUI
import SwiftData

/// Adds or edits one code of a device.
struct CodeEditorView: View {
    let device: Device
    let existing: PairingCode?
    let initial: ParsedCode?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var type: CodeType = .homeKit
    @State private var label = ""
    @State private var value = ""
    @State private var secondary = ""
    @State private var qrPayload: String?
    @State private var capture: CaptureSource?
    @State private var errorText: String?
    @State private var saved = 0
    @State private var loaded = false
    @State private var lastParsed: ParsedCode?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(CodeType.allCases) { t in
                            Label(t.title, systemImage: t.symbol).tag(t)
                        }
                    }
                    TextField("Label (optional)", text: $label, prompt: Text("For example: Matter code from the Eve app"))
                }

                Section {
                    codeField
                    if let secondaryLabel = type.secondaryLabel {
                        TextField(secondaryLabel, text: $secondary, prompt: Text(verbatim: type.secondaryPlaceholder))
                            .font(.body.monospaced())
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            #endif
                    }
                    validationRow
                } header: {
                    Text(verbatim: type.valueLabel)
                } footer: {
                    Text(verbatim: type.hint)
                }

                if let qrPayload {
                    Section("QR code") {
                        HStack(spacing: 14) {
                            if let img = QRCode.image(qrPayload) {
                                img.resizable().interpolation(.none).scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .padding(6)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                            }
                            Text(verbatim: qrPayload)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                            Spacer()
                            Button(role: .destructive) { self.qrPayload = nil } label: {
                                Label("Remove QR code", systemImage: "xmark.circle.fill").labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section("Fill in automatically") {
                    CaptureButtons(source: $capture)
                }

                if let errorText {
                    Section { Text(verbatim: errorText).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil ? LocalizedStringKey("New code") : LocalizedStringKey("Edit code"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(value.trimmed.isEmpty && secondary.trimmed.isEmpty)
                }
            }
            .codeCapture(source: $capture, preferred: type) { apply($0) }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear(perform: load)
        }
        .modalTracked()
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private var codeField: some View {
        TextField(type.valueLabel, text: $value, prompt: Text(verbatim: type.placeholder), axis: type == .zigbee || type == .other ? .vertical : .horizontal)
            .font(.title3.monospaced())
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(type.isNumeric ? .numberPad : .asciiCapable)
            .textInputAutocapitalization(type == .wifi || type == .other ? .never : .characters)
            #endif
    }

    @ViewBuilder
    private var validationRow: some View {
        switch CodeParser.validate(type, value, secondary: secondary) {
        case .valid:
            Label {
                Text(verbatim: CodeParser.format(type, value))
            } icon: {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.mint)
            }
            .font(.callout.monospaced())
        case .warning(let text):
            Label {
                Text(verbatim: text)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .font(.callout)
        case .unknown:
            EmptyView()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            type = existing.type
            label = existing.label
            if let s = existing.secret {
                value = CodeParser.format(existing.type, s.value)
                secondary = s.secondary
                qrPayload = s.qrPayload
            }
        } else if let initial {
            apply(initial)
        }
    }

    private func apply(_ p: ParsedCode) {
        lastParsed = p
        type = p.type
        value = CodeParser.format(p.type, p.value)
        if !p.secondary.isEmpty { secondary = p.secondary }
        qrPayload = p.qrPayload
    }

    private func save() {
        let normalized = CodeParser.normalize(type, value)
        // Drop a QR payload that no longer matches the typed code.
        var payload = qrPayload
        if let p = payload, let parsed = CodeParser.detect(p), parsed.type == type,
           !parsed.value.isEmpty, parsed.value != normalized {
            payload = nil
        }
        var secret = CodeSecret(value: normalized, secondary: secondary.trimmed, qrPayload: payload)
        if let payload { secret.qrPNG = QRCode.pngData(payload) }

        let code = existing ?? PairingCode(type: type)
        code.type = type
        code.label = label.trimmed
        do {
            try code.setSecret(secret)
        } catch {
            errorText = error.localizedDescription
            return
        }
        if existing == nil {
            context.insert(code)
            if device.codes == nil { device.codes = [] }
            device.codes?.append(code)
        }
        device.touch()
        try? context.save()
        #if os(iOS)
        KeySync.shared.pushKey()
        #endif
        saved += 1
        let device = self.device
        if let parsed = lastParsed {
            // Fill empty details of the device from the scanned code.
            Task { @MainActor in
                guard let info = await DeviceLookup.info(for: parsed) else { return }
                if device.manufacturer.isEmpty { device.manufacturer = info.manufacturer }
                if device.model.isEmpty { device.model = info.model }
                if device.kind == .other, let k = info.kind { device.kind = k }
                if device.logoDomain.isEmpty, let domain = info.brandDomain { device.logoDomain = domain }
                device.touch()
                try? device.modelContext?.save()
                await DeviceLookup.fetchLogoIfNeeded(for: device)
            }
        }
        dismiss()
    }
}
