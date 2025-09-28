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
        var currentScore: String
        var serverName: String
        var matchStatus: String // "In Progress", "Completed"
        var lastUpdated: Date
    }

    // Static data that doesn't change during the activity
    var matchId: String
    var startTime: Date
}