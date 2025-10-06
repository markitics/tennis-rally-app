// PhoneWatchConnectivity.swift
// Add this to your iOS app target

import Foundation
import WatchConnectivity

class PhoneWatchConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchConnectivity()

    var onWatchAction: ((String) -> String?)?  // Returns score after recording point

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("iPhone session activated: \(activationState.rawValue)")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 Received from watch: \(message)")

        guard let action = message["action"] as? String else {
            replyHandler(["error": "No action"])
            return
        }

        // Call the handler (will be set in ContentView)
        if let score = onWatchAction?(action) {
            replyHandler(["score": score])
        } else {
            replyHandler(["error": "No handler set"])
        }
    }
}
