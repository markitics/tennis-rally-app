//
//  LiveActivityIntents.swift
//  TennisTrackerWidget
//
//  WIDGET TARGET: Placeholder implementations (never run - just for compilation)
//  The real implementations are in the main app target!
//

import AppIntents
import Foundation

// WIDGET: Placeholder - this never runs!
struct WinnerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Winner"
    static var description = IntentDescription("Record a winner point for Mark")

    func perform() async throws -> some IntentResult {
        // Empty placeholder - real implementation is in main app target
        return .result()
    }
}

// WIDGET: Placeholder - this never runs!
struct UnforcedErrorIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record Unforced Error"
    static var description = IntentDescription("Record an unforced error by Mark")

    func perform() async throws -> some IntentResult {
        // Empty placeholder - real implementation is in main app target
        return .result()
    }
}