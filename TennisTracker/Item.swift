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
    case ace           // Service winner (replaces specific ace tracking)
    case winner        // Any other (non-ace) winner (merges dropShotWinner + otherWinner)
    case doubleFault   // Service error (unchanged)
    case unforcedError // Rally error (unchanged)
    // Removed: unknown (assume everything is tracked)
}

@Model
final class Match {
    @Attribute(.unique) var id: UUID
    var playerOne: Player
    var playerTwo: Player
    var matchDate: Date
    var firstServerID: UUID
    var isCompleted: Bool = false
    var title: String?
    var notes: String?
    var latitude: Double?
    var longitude: Double?

    // Use proper SwiftData relationships
    @Relationship(deleteRule: .cascade, inverse: \Point.match)
    var points: [Point] = []

    // Track who served first in each tiebreak for correct next-set server (stored as string)
    private var tiebreakFirstServersData: String = ""

    // Computed property for accessing tiebreak first servers
    var tiebreakFirstServers: [UUID] {
        get {
            guard !tiebreakFirstServersData.isEmpty else { return [] }
            let uuidStrings = tiebreakFirstServersData.components(separatedBy: ",")
            return uuidStrings.compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            tiebreakFirstServersData = newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

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
        title: String? = nil,
        notes: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.playerOne = playerOne
        self.playerTwo = playerTwo
        self.matchDate = matchDate
        self.firstServerID = firstServerID
        self.isCompleted = isCompleted
        self.title = title
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
    }
}

@Model
final class Point {
    @Attribute(.unique) var id: UUID
    var winner: Player
    var loser: Player
    var type: PointType
    var setNumber: Int
    var gameNumber: Int
    var timestamp: Date

    // Relationship back to match
    var match: Match?

    init(
        id: UUID = UUID(),
        match: Match,
        winner: Player,
        loser: Player,
        type: PointType,
        setNumber: Int,
        gameNumber: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.match = match
        self.winner = winner
        self.loser = loser
        self.type = type
        self.setNumber = setNumber
        self.gameNumber = gameNumber
        self.timestamp = timestamp
    }
}
