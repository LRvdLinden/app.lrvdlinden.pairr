import SwiftUI
import SwiftData

enum Links {
    /// Website of Pairr: Dutch at /, English at /en/.
    private static var base: String {
        Locale.current.language.languageCode?.identifier == "nl" ? "https://pairr.lrvdlinden.app" : "https://pairr.lrvdlinden.app/en"
    }
    static var privacy: URL { URL(string: base + "/privacy/")! }
    static var support: URL { URL(string: base + "/support/")! }
}

struct SettingsView: View {
    var onImportFromHome: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var devices: [Device]
    @AppStorage("security.lockEnabled") private var lockEnabled = false
    @AppStorage("security.revealCodes") private var revealCodes = false
    @AppStorage("ui.appearance") private var appearance: AppearanceSetting = .system
    @AppStorage("onboarding.done") private var onboardingDone = true
    @AppStorage(DeviceLookup.enabledKey) private var lookupOnline = true
    @AppStorage("ui.showLogos") private var showLogos = true
    @State private var cloud = CloudStatus.shared
    @State private var showWhatsNew = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: lockBinding) {
                        Label {
                            Text("Lock Pairr")
                        } icon: {
                            Image(systemName: AppState.biometrySymbol)
                        }
                    }
                    Toggle(isOn: $revealCodes) {
                        Label("Show codes right away", systemImage: "eye")
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("The lock uses Face ID, Touch ID or your passcode. With “Show codes right away” off, codes stay hidden until you tap them.")
                }

                Section {
                    LabeledContent {
                        Text(verbatim: cloud.accountText).foregroundStyle(.secondary)
                    } label: {
                        Label("iCloud sync", systemImage: "icloud")
                    }
                    NavigationLink {
                        DataView()
                    } label: {
                        Label("Backup, export and import", systemImage: "externaldrive.badge.icloud")
                    }
                    #if os(iOS)
                    Button {
                        onImportFromHome()
                    } label: {
                        Label("Import from the Home app", systemImage: "house")
                    }
                    #endif
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Everything is stored in your own iCloud. Deleting the app doesn't delete your data: after reinstalling, it comes back.")
                }

                Section {
                    Toggle(isOn: $lookupOnline) {
                        Label("Look up product details online", systemImage: "magnifyingglass")
                    }
                    Toggle(isOn: $showLogos) {
                        Label("Show brand logos", systemImage: "seal")
                    }
                } header: {
                    Text("Product details")
                } footer: {
                    Text("After a scan, Pairr fills in the brand, model and type: from the public Matter register of the CSA, the Zigbee address or the Hue code. Logos come from the manufacturer's own website. Your codes are never sent.")
                }

                Section("Appearance") {
                    Picker(selection: $appearance) {
                        ForEach(AppearanceSetting.allCases) { Text($0.label).tag($0) }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                }

                Section {
                    Link(destination: Links.privacy) { Label("Privacy policy", systemImage: "hand.raised") }
                    Link(destination: Links.support) { Label("Support and contact", systemImage: "questionmark.circle") }
                    Button { showWhatsNew = true } label: { Label("What's new", systemImage: "sparkles") }
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onboardingDone = false }
                    } label: {
                        Label("Show the welcome screen", systemImage: "hand.wave")
                    }
                }

                Section {
                    MoreAppsCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: MoreAppsText.current.section)
                }

                Section {
                    AppInfoFooter()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
            .task { await cloud.refresh() }
        }
        .modalTracked()
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    /// Turning the lock on first checks that authentication works.
    private var lockBinding: Binding<Bool> {
        Binding(get: { lockEnabled }, set: { on in
            if on {
                Task {
                    if await AppState.authenticate(reason: String(localized: "Turn on the lock for Pairr.")) {
                        lockEnabled = true
                    }
                }
            } else {
                lockEnabled = false
            }
        })
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    item("key.viewfinder", "All your codes in one place", "HomeKit, Matter, Zigbee, Philips Hue, Z-Wave, Wi-Fi and PIN codes per device.")
                    item("camera.viewfinder", "Scan and read from photos", "Scan QR codes and printed codes, or read them from a photo of the box or bulb fitting.")
                    item("house", "Import from the Home app", "Your homes, rooms and accessories, with re-paired devices recognised by serial number.")
                    item("qrcode", "Show the QR code again", "Large and bright, so you can pair a device straight from Pairr or your Apple Watch.")
                    item("lock.shield", "Encrypted and synced", "Codes and photos are encrypted, synced through iCloud and backed up weekly to iCloud Drive.")
                    item("square.and.arrow.up", "Export and import", "PDF to print, CSV, Markdown and a backup with password.")
                } header: {
                    Text(verbatim: "1.0.0")
                }
            }
            .navigationTitle("What's new")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .modalTracked()
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private func item(_ symbol: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
