import SwiftUI
import SwiftData

@main
struct PairrApp: App {
    @AppStorage("ui.appearance") private var appearance: AppearanceSetting = .system
    @State private var appState = AppState()
    private let container = PairrStore.makeContainer()

    init() {
        #if os(iOS)
        KeySync.shared.activate()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(appearance.colorScheme)
                .tint(Theme.accent)
                .task { AutoBackup.runIfDue(container: container) }
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New device") { appState.pendingAction = .newDevice }
                    .keyboardShortcut("n")
            }
        }
        #endif
    }
}
