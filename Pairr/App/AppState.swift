import SwiftUI
import LocalAuthentication

/// App-wide state: the lock, open sheets and actions from the Mac menu.
@Observable
final class AppState {
    enum Action: Equatable { case newDevice }

    var isLocked: Bool
    /// Number of sheets currently open (the review prompt waits for 0).
    var openModals = 0
    var pendingAction: Action?
    private var authenticating = false

    init() {
        isLocked = UserDefaults.standard.bool(forKey: "security.lockEnabled")
    }

    var lockEnabled: Bool { UserDefaults.standard.bool(forKey: "security.lockEnabled") }

    func lock() {
        if lockEnabled { isLocked = true }
    }

    @MainActor
    func unlock() async {
        guard isLocked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }
        let ok = await Self.authenticate(reason: String(localized: "Unlock Pairr to see your pairing codes."))
        if ok { isLocked = false }
    }

    /// Face ID / Touch ID / Optic ID, with the device passcode as fallback.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on this device: nothing to lock with.
            return true
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return String(localized: "your passcode")
        }
    }

    static var biometrySymbol: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }
}

/// Counts open sheets and covers them with the lock screen when the app locks.
struct ModalTracked: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .overlay {
                if appState.isLocked { LockView() }
            }
            .onAppear { appState.openModals += 1 }
            .onDisappear { appState.openModals = max(0, appState.openModals - 1) }
    }
}

extension View {
    func modalTracked() -> some View { modifier(ModalTracked()) }
}
