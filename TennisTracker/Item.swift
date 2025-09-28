//
//  Models.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum PointType: String, Codable, CaseIterable {
    case dropShotWinner
    case otherWinner
    case doubleFault
    case unforcedError
    case unknown
}

@Model
final class Match {
    @Attribute(.unique) var id: UUID
    var playerOne: Player
    var playerTwo: Player
    var matchDate: Date
    var firstServerID: UUID
    var isCompleted: Bool = false
    var notes: String?

    // Using simple array instead of @Relationship to avoid SwiftData corruption
    var points: [Point] = []

    // Computed property that returns points sorted chronologically
    var sortedPoints: [Point] {
        return points.sorted(by: { $0.timestamp < $1.timestamp })
    }

    init(
        id: UUID = UUID(),
        playerOne: Player,
        playerTwo: Player,
        matchDate: Date = Date(),
        firstServerID: UUID,
        isCompleted: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.playerOne = playerOne
        self.playerTwo = playerTwo
        self.matchDate = matchDate
        self.firstServerID = firstServerID
        self.isCompleted = isCompleted
        self.notes = notes
    }
}

@Model
final class Point {
    @Attribute(.unique) var id: UUID
    var matchID: UUID  // Store ID instead of relationship to avoid circular reference

    var winner: Player
    var loser: Player
    var type: PointType
    var setNumber: Int
    var timestamp: Date

    init(
        id: UUID = UUID(),
        matchID: UUID,
        winner: Player,
        loser: Player,
        type: PointType,
        setNumber: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.matchID = matchID
        self.winner = winner
        self.loser = loser
        self.type = type
        self.setNumber = setNumber
        self.timestamp = timestamp
    }
}