import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The code large and bright, ready to scan with the Home app or a Matter app.
struct CodeDisplayView: View {
    let code: PairingCode
    let deviceName: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = 0
    #if os(iOS)
    @State private var previousBrightness: CGFloat?
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CodeTypeBadge(type: code.type)
                    if let secret = code.secret {
                        visual(secret)
                        VStack(spacing: 6) {
                            Text(verbatim: code.type.valueLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(verbatim: CodeParser.format(code.type, secret.value))
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.4)
                                .lineLimit(3)
                                .textSelection(.enabled)
                            if !secret.secondary.isEmpty, let label = code.type.secondaryLabel {
                                Text(verbatim: "\(label): \(code.type == .zigbee ? CodeParser.formatIEEE(secret.secondary) : secret.secondary)")
                                    .font(.callout.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        Button {
                            Clipboard.copy(CodeParser.format(code.type, secret.value))
                            copied += 1
                        } label: {
                            Label("Copy code", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .sensoryFeedback(.success, trigger: copied)
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        ContentUnavailableView("Can't decrypt this code",
                                               systemImage: "exclamationmark.lock",
                                               description: Text("This device doesn't have the key yet. Check that iCloud Keychain is on, or restore a backup."))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(deviceName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .modalTracked()
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
        #if os(iOS)
        .onAppear { boostBrightness() }
        .onDisappear { restoreBrightness() }
        #endif
    }

    @ViewBuilder
    private func visual(_ secret: CodeSecret) -> some View {
        if let payload = secret.qrPayload, let image = QRCode.image(payload) {
            image
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: 300)
                .padding(22)
                .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                .accessibilityLabel("QR code")
        } else if code.type == .homeKit {
            HomeKitLabel(code: secret.value, width: 300)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        }
    }

    private var hint: LocalizedStringKey {
        switch code.type {
        case .homeKit: "In the Home app tap + → Add Accessory and scan this code."
        case .matter: "Scan this code in the Home app, Google Home, SmartThings, Homey or another Matter app."
        case .hue: "In the Hue app: Settings → Lights → Add light → Use serial number."
        case .zigbee: "Enter the install code and IEEE address in your Zigbee hub or Zigbee2MQTT."
        case .zwave: "Use the DSK or SmartStart code in your Z-Wave controller."
        default: "Tap the code to select it."
        }
    }

    #if os(iOS)
    private var screen: UIScreen? {
        (UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene)?.screen
    }

    private func boostBrightness() {
        guard let screen, previousBrightness == nil else { return }
        previousBrightness = screen.brightness
        screen.brightness = 1
    }

    private func restoreBrightness() {
        guard let screen, let previousBrightness else { return }
        screen.brightness = previousBrightness
        self.previousBrightness = nil
    }
    #endif
}
