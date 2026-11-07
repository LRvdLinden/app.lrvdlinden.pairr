import SwiftUI

/// Three welcome screens, shown on first start (and again from Settings).
struct OnboardingView: View {
    @AppStorage("onboarding.done") private var done = false
    @AppStorage("security.lockEnabled") private var lockEnabled = false
    @State private var page = 0
    @State private var cloud = CloudStatus.shared

    private let pages = 3

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            Group {
                switch page {
                case 0: welcome
                case 1: capture
                default: privacy
                }
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            Spacer(minLength: 20)

            HStack(spacing: 8) {
                ForEach(0..<pages, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Color.secondary.opacity(0.3))
                        .frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(.spring(response: 0.35), value: page)
            .padding(.bottom, 24)
            .accessibilityHidden(true)

            HStack {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button {
                    if page < pages - 1 { withAnimation { page += 1 } } else { done = true }
                } label: {
                    Text(page < pages - 1 ? LocalizedStringKey("Next") : LocalizedStringKey("Get started"))
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            PairrLogo(size: 150)
                .padding(18)
                .background(IconPalette.background, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            Text("Welcome to Pairr")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Keep every pairing code of your smart home in one place: HomeKit, Matter, Zigbee, Philips Hue and Z-Wave.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                ForEach([CodeType.homeKit, .matter, .zigbee, .hue, .zwave]) { CodeTypeBadge(type: $0, compact: true) }
            }
            if cloud.hasCloudData {
                Label("Your Pairr data was found in iCloud and is being restored.", systemImage: "icloud.and.arrow.down")
                    .font(.callout)
                    .padding(12)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var capture: some View {
        VStack(spacing: 22) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Scan, import or type")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 14) {
                feature("camera.viewfinder", "Scan the QR code or the code on a sticker.")
                feature("photo.on.rectangle", "Read a code from a photo of the box or the bulb fitting.")
                feature("house", "Import your accessories from the Home app.")
                feature("qrcode", "Show the QR code again to pair a device.")
            }
        }
    }

    private var privacy: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(Theme.mint)
            Text("Safe and private")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Your codes are encrypted and synced through your own iCloud. If you delete the app, everything comes back when you install it again.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Toggle(isOn: $lockEnabled) {
                Label("Lock Pairr", systemImage: AppState.biometrySymbol)
            }
            .toggleStyle(.switch)
            .padding(14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 28)
        }
        .font(.body)
    }
}
