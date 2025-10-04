//
//  LiveActivityAttributes.swift
//  TennisTracker
//
//  Created for Live Activities support
//

import Foundation
import ActivityKit

struct TennisMatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Current match state
        var playerOneName: String
        var playerTwoName: String
        var currentScore: String // Full score string (for backwards compatibility)
        var setsAndGamesScore: String // Just completed sets/games (e.g., "6-4, 3-2")
        var inGameScoreP1: String // Player 1's current game score (e.g., "15")
        var inGameScoreP2: String // Player 2's current game score (e.g., "30")
        var serverName: String
        var matchStatus: String // "In Progress", "Completed"
        var lastUpdated: Date
    }

    // Static data that doesn't change during the activity
    var matchId: String
    var startTime: Date
}