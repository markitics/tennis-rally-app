// WatchApp-ContentView.swift
// Main watch app with 2-screen TabView

import SwiftUI
import WatchConnectivity
import Combine

struct WatchAppContentView: View {
    @StateObject private var connectivity = WatchConnectivityManager()
    @State private var currentTab = 1  // Start on Point Entry screen (95% usage)

    var body: some View {
        TabView(selection: $currentTab) {
            // Screen 1: Score Display
            ScoreDisplayView(
                gameScore: connectivity.currentGameScore,
                setScore: connectivity.currentSetScore,
                serverName: connectivity.serverName
            )
            .tag(0)

            // Screen 2: Point Entry (default)
            PointEntryView(connectivity: connectivity)
                .tag(1)
        }
        .tabViewStyle(.page)
    }
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var currentGameScore = "0-0"
    @Published var currentSetScore = "0-0"
    @Published var serverName = "Mark"

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendAction(_ action: String) {
        guard WCSession.default.isReachable else {
            print("iPhone not reachable")
            return
        }

        WCSession.default.sendMessage(["action": action], replyHandler: { reply in
            if let score = reply["score"] as? String {
                self.parseScore(score)
            }
        })
    }

    private func parseScore(_ fullScore: String) {
        // Parse "2-1, 40-30" into set score and game score
        let parts = fullScore.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        DispatchQueue.main.async {
            if parts.count >= 2 {
                self.currentSetScore = parts[0]  // "2-1"
                self.currentGameScore = parts[1]  // "40-30"
            } else {
                self.currentGameScore = fullScore
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch session activated: \(activationState.rawValue)")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let score = message["score"] as? String {
            parseScore(score)
        }
        if let server = message["server"] as? String {
            DispatchQueue.main.async {
                self.serverName = server
            }
        }
    }
}
