import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarding.done") private var onboardingDone = false
    @State private var showSplash = true
    @State private var cloud = CloudStatus.shared

    var body: some View {
        ZStack {
            ContentView()
                .blur(radius: shielded ? 24 : 0)
                .allowsHitTesting(!appState.isLocked && onboardingDone)

            if !showSplash && !onboardingDone {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(2)
            } else if !showSplash && appState.isLocked {
                LockView()
                    .transition(.opacity)
                    .zIndex(3)
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.3)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isLocked)
        .animation(.easeInOut(duration: 0.3), value: onboardingDone)
        .task { await cloud.refresh() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appState.lock()
            case .active: Task { await cloud.refresh() }
            default: break
            }
        }
        .reviewPrompt(isCalm: !showSplash && onboardingDone && !appState.isLocked && appState.openModals == 0)
    }

    /// Hide the codes in the app switcher and behind the lock screen.
    private var shielded: Bool {
        appState.lockEnabled && (scenePhase != .active || appState.isLocked)
    }
}
