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
    var winner: Player
    var loser: Player
    var type: PointType
    var setNumber: Int
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
        timestamp: Date = Date()
    ) {
        self.id = id
        self.match = match
        self.winner = winner
        self.loser = loser
        self.type = type
        self.setNumber = setNumber
        self.timestamp = timestamp
    }
}