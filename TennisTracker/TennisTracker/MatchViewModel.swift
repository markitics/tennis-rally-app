//
//  MatchViewModel.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import Foundation
import SwiftUI
import Combine

final class MatchViewModel: ObservableObject {
    @Published private(set) var match: Match?
    @Published var cursor: Int = 0

    // In-memory cache to avoid SwiftData lag
    @Published var cachedPoints: [Point] = []

    var derivedState: DerivedMatchState {
        guard let match = match else {
            return DerivedMatchState(
                setScores: [],
                inGameDisplay: ("0", "0"),
                leaderID: nil,
                trailerID: nil,
                currentScoreString: "0-0",
                endScoreString: "0-0",
                setsAndGamesOnly: "0-0",
                inTiebreak: false
            )
        }

        return ScoreEngine.compute(
            visiblePoints: Array(cachedPoints.prefix(cursor)),
            fullPoints: cachedPoints,
            p1: match.playerOne.id,
            p2: match.playerTwo.id,
            firstServerID: match.firstServerID
        )
    }

    var canBack: Bool {
        cursor > 0
    }

    var canForward: Bool {
        return cursor < cachedPoints.count
    }

    func setMatch(_ newMatch: Match) {
        match = newMatch
        cachedPoints = newMatch.sortedPoints
        cursor = cachedPoints.count
    }

    func addPointToCache(_ point: Point) {
        cachedPoints.append(point)
        cursor = cachedPoints.count
    }

    func back() {
        if canBack {
            cursor -= 1
        }
    }

    func forward() {
        if canForward {
            cursor += 1
        }
    }
}