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
        let actionID = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970

        print("🏆 WINNER INTENT START - ID: \(actionID)")
        print("🏆   Timestamp: \(timestamp)")
        print("🏆   Bundle: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🏆   Process: \(ProcessInfo.processInfo.processName)")

        // Post notification for PlayView to handle
        // This works because we're in the MAIN APP process!
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: [
                    "pointType": "winner",
                    "player": "Mark",
                    "actionID": actionID,
                    "timestamp": timestamp
                ]
            )
            print("🏆 WINNER INTENT END - Posted notification with ID: \(actionID)")
        }

        return .result()
    }
}

// MAIN APP: Intent for recording an unforced error - runs in MAIN APP PROCESS
struct UnforcedErrorIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Unforced Error"
    static var description = IntentDescription("Record an unforced error by Mark")

    func perform() async throws -> some IntentResult {
        let actionID = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970

        print("🙈 ERROR INTENT START - ID: \(actionID)")
        print("🙈   Timestamp: \(timestamp)")
        print("🙈   Bundle: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🙈   Process: \(ProcessInfo.processInfo.processName)")

        // Post notification for PlayView to handle
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: [
                    "pointType": "unforcedError",
                    "player": "Mark",
                    "actionID": actionID,
                    "timestamp": timestamp
                ]
            )
            print("🙈 ERROR INTENT END - Posted notification with ID: \(actionID)")
        }

        return .result()
    }
}

// MAIN APP: Intent for recording an ace
struct AceIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Ace"
    static var description = IntentDescription("Record an ace")

    func perform() async throws -> some IntentResult {
        let actionID = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970

        print("🎾 ACE INTENT START - ID: \(actionID)")
        print("🎾   Timestamp: \(timestamp)")

        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: [
                    "pointType": "ace",
                    "player": "server",
                    "actionID": actionID,
                    "timestamp": timestamp
                ]
            )
            print("🎾 ACE INTENT END - Posted notification with ID: \(actionID)")
        }

        return .result()
    }
}

// MAIN APP: Intent for recording a double fault
struct DoubleFaultIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Double Fault"
    static var description = IntentDescription("Record a double fault")

    func perform() async throws -> some IntentResult {
        let actionID = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970

        print("💥 DF INTENT START - ID: \(actionID)")
        print("💥   Timestamp: \(timestamp)")

        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: [
                    "pointType": "doubleFault",
                    "player": "server",
                    "actionID": actionID,
                    "timestamp": timestamp
                ]
            )
            print("💥 DF INTENT END - Posted notification with ID: \(actionID)")
        }

        return .result()
    }
}

// MAIN APP: Intent for Jeff hitting a winner
struct JeffWinnerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Jeff Winner"
    static var description = IntentDescription("Record a winner by Jeff")

    func perform() async throws -> some IntentResult {
        let actionID = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970

        print("🏆 JEFF WINNER INTENT START - ID: \(actionID)")
        print("🏆   Timestamp: \(timestamp)")

        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: [
                    "pointType": "winner",
                    "player": "Jeff",
                    "actionID": actionID,
                    "timestamp": timestamp
                ]
            )
            print("🏆 JEFF WINNER INTENT END - Posted notification with ID: \(actionID)")
        }

        return .result()
    }
}

// MAIN APP: Intent for Jeff making an error
struct JeffErrorIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Jeff Error"
    static var description = IntentDescription("Record an unforced error by Jeff")

    func perform() async throws -> some IntentResult {
        let actionID = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970

        print("🙈 JEFF ERROR INTENT START - ID: \(actionID)")
        print("🙈   Timestamp: \(timestamp)")

        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: [
                    "pointType": "unforcedError",
                    "player": "Jeff",
                    "actionID": actionID,
                    "timestamp": timestamp
                ]
            )
            print("🙈 JEFF ERROR INTENT END - Posted notification with ID: \(actionID)")
        }

        return .result()
    }
}