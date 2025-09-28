//
//  LiveActivityIntents.swift
//  TennisTrackerWidget
//
//  App Intents for Live Activity buttons
//

import AppIntents
import Foundation

// Intent for recording a winner
struct WinnerIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Winner"
    static var description = IntentDescription("Record a winner point for Mark")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let timestamp = Date()
        print("🏆 WINNER INTENT [\(timestamp)]: Starting execution from Live Activity")

        // Use the working URL scheme approach but from within the Intent
        if let url = URL(string: "tennistracker://winner") {
            print("🏆 WINNER: Opening URL scheme to trigger main app...")

            // This will trigger the main app's handleURL function
            await UIApplication.shared.open(url)

            print("🏆 WINNER: ✅ URL scheme triggered successfully")
        } else {
            print("🏆 WINNER: ❌ Failed to create URL")
        }

        print("🏆 WINNER INTENT [\(timestamp)]: Completed execution")
        return .result()
    }
}

// Intent for recording an unforced error
struct UnforcedErrorIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Unforced Error"
    static var description = IntentDescription("Record an unforced error by Mark")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let timestamp = Date()
        print("🙈 ERROR INTENT [\(timestamp)]: Starting execution from Live Activity")

        // Use the working URL scheme approach but from within the Intent
        if let url = URL(string: "tennistracker://error") {
            print("🙈 ERROR: Opening URL scheme to trigger main app...")

            // This will trigger the main app's handleURL function
            await UIApplication.shared.open(url)

            print("🙈 ERROR: ✅ URL scheme triggered successfully")
        } else {
            print("🙈 ERROR: ❌ Failed to create URL")
        }

        print("🙈 ERROR INTENT [\(timestamp)]: Completed execution")
        return .result()
    }
}