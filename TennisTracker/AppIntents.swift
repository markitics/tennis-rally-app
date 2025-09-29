//
//  AppIntents.swift
//  TennisTracker
//
//  Shared App Intent definitions for both main app and widget extension
//

import AppIntents
import Foundation

// Intent for recording a winner - executes in background
struct WinnerIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Winner"
    static var description = IntentDescription("Record a winner point for Mark")
    static var openAppWhenRun: Bool = false // Critical: keeps app closed

    func perform() async throws -> some IntentResult {
        let timestamp = Date()
        print("🏆 WINNER INTENT [\(timestamp)]: Starting background execution")

        // Add more debugging at the very start
        print("🏆 WINNER: App Intent is executing - this should appear in console")
        print("🏆 WINNER: Bundle identifier: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🏆 WINNER: Process name: \(ProcessInfo.processInfo.processName)")

        // Save action to App Group UserDefaults for main app to process
        let defaults = UserDefaults(suiteName: "group.com.markmoriarty.apps.TennisTracker")

        let actionData = [
            "action": "recordPoint",
            "pointType": "winner",
            "player": "Mark",
            "timestamp": timestamp.timeIntervalSince1970
        ] as [String: Any]

        print("🏆 WINNER: About to save action data: \(actionData)")
        print("🏆 WINNER: UserDefaults object: \(defaults != nil ? "EXISTS" : "NIL")")

        defaults?.set(actionData, forKey: "pendingAction")
        let syncResult = defaults?.synchronize() ?? false

        print("🏆 WINNER: Synchronize result: \(syncResult)")

        // Verify the data was written
        let readBack = defaults?.dictionary(forKey: "pendingAction")
        print("🏆 WINNER: Read back from UserDefaults: \(readBack ?? [:])")

        print("🏆 WINNER: Background action saved to shared storage")

        // Trigger main app to check for pending actions using push notification
        // This will work even when app is backgrounded
        await triggerMainAppUpdate()

        return .result()
    }

    private func triggerMainAppUpdate() async {
        // Use CFNotificationCenter for cross-process communication
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName("com.tennis.tracker.widgetAction" as CFString),
            nil, nil, true
        )
        print("🏆 WINNER: Sent darwin notification to main app")
    }
}

// Intent for recording an unforced error - executes in background
struct UnforcedErrorIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Unforced Error"
    static var description = IntentDescription("Record an unforced error by Mark")
    static var openAppWhenRun: Bool = false // Critical: keeps app closed

    func perform() async throws -> some IntentResult {
        let timestamp = Date()
        print("🙈 ERROR INTENT [\(timestamp)]: Starting background execution")

        // Add more debugging at the very start
        print("🙈 ERROR: App Intent is executing - this should appear in console")
        print("🙈 ERROR: Bundle identifier: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🙈 ERROR: Process name: \(ProcessInfo.processInfo.processName)")

        // Save action to App Group UserDefaults for main app to process
        let defaults = UserDefaults(suiteName: "group.com.markmoriarty.apps.TennisTracker")

        let actionData = [
            "action": "recordPoint",
            "pointType": "unforcedError",
            "player": "Mark",
            "timestamp": timestamp.timeIntervalSince1970
        ] as [String: Any]

        print("🙈 ERROR: About to save action data: \(actionData)")
        print("🙈 ERROR: UserDefaults object: \(defaults != nil ? "EXISTS" : "NIL")")

        defaults?.set(actionData, forKey: "pendingAction")
        let syncResult = defaults?.synchronize() ?? false

        print("🙈 ERROR: Synchronize result: \(syncResult)")

        // Verify the data was written
        let readBack = defaults?.dictionary(forKey: "pendingAction")
        print("🙈 ERROR: Read back from UserDefaults: \(readBack ?? [:])")

        print("🙈 ERROR: Background action saved to shared storage")

        // Trigger main app to check for pending actions
        await triggerMainAppUpdate()

        return .result()
    }

    private func triggerMainAppUpdate() async {
        // Use CFNotificationCenter for cross-process communication
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName("com.tennis.tracker.widgetAction" as CFString),
            nil, nil, true
        )
        print("🙈 ERROR: Sent darwin notification to main app")
    }
}