//
//  AppIntents.swift
//  TennisTracker
//
//  MAIN APP TARGET: LiveActivityIntent implementations that run in app process
//  These have direct access to SwiftData and can call app functions!
//

import AppIntents
import Foundation

// MAIN APP: Intent for recording a winner - runs in MAIN APP PROCESS
struct WinnerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Winner"
    static var description = IntentDescription("Record a winner point for Mark")

    func perform() async throws -> some IntentResult {
        print("🏆 WINNER: Running in MAIN APP process!")
        print("🏆 Bundle: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🏆 Process: \(ProcessInfo.processInfo.processName)")

        // Post notification for PlayView to handle
        // This works because we're in the MAIN APP process!
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: ["pointType": "winner", "player": "Mark"]
            )
            print("🏆 Posted notification - PlayView will handle it!")
        }

        return .result()
    }
}

// MAIN APP: Intent for recording an unforced error - runs in MAIN APP PROCESS
struct UnforcedErrorIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Unforced Error"
    static var description = IntentDescription("Record an unforced error by Mark")

    func perform() async throws -> some IntentResult {
        print("🙈 ERROR: Running in MAIN APP process!")
        print("🙈 Bundle: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🙈 Process: \(ProcessInfo.processInfo.processName)")

        // Post notification for PlayView to handle
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: ["pointType": "unforcedError", "player": "Mark"]
            )
            print("🙈 Posted notification - PlayView will handle it!")
        }

        return .result()
    }
}