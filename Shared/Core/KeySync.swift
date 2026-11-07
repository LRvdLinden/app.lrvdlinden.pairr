#if os(iOS) || os(watchOS)
import Foundation
import WatchConnectivity

/// Hands the vault key from the iPhone to the Apple Watch, in memory only.
final class KeySync: NSObject, WCSessionDelegate {
    static let shared = KeySync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        #if os(iOS)
        pushKey()
        #else
        requestKeyIfNeeded()
        #endif
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func sessionReachabilityDidChange(_ session: WCSession) { pushKey() }

    /// Sends the key to the watch when it is reachable.
    func pushKey() {
        let s = WCSession.default
        guard WCSession.isSupported(), s.activationState == .activated, s.isPaired, s.isWatchAppInstalled,
              s.isReachable, let key = CodeVault.exportKey() else { return }
        s.sendMessage(["vaultKey": key], replyHandler: nil, errorHandler: nil)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if message["request"] as? String == "vaultKey", let key = CodeVault.exportKey() {
            replyHandler(["vaultKey": key])
        } else {
            replyHandler([:])
        }
    }
    #else
    func requestKeyIfNeeded() {
        let s = WCSession.default
        guard WCSession.isSupported(), s.activationState == .activated, s.isReachable, !CodeVault.hasKey else { return }
        s.sendMessage(["request": "vaultKey"], replyHandler: { reply in
            if let key = reply["vaultKey"] as? Data { CodeVault.importKey(key) }
        }, errorHandler: nil)
    }

    func sessionReachabilityDidChange(_ session: WCSession) { requestKeyIfNeeded() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let key = message["vaultKey"] as? Data { CodeVault.importKey(key) }
    }
    #endif
}
#endif
