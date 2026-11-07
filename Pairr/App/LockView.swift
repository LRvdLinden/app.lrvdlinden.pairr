import SwiftUI

/// Shown while Pairr is locked; asks for Face ID right away.
struct LockView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            IconPalette.background.ignoresSafeArea()
            VStack(spacing: 26) {
                PairrLogo(size: 120)
                Text("Pairr is locked")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Button {
                    Task { await appState.unlock() }
                } label: {
                    Label("Unlock", systemImage: AppState.biometrySymbol)
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .task { await appState.unlock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await appState.unlock() } }
        }
    }
}
