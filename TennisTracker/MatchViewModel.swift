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

    var derivedState: DerivedMatchState {
        guard let match = match else {
            return DerivedMatchState(
                setScores: [],
                inGameDisplay: ("0", "0"),
                leaderID: nil,
                trailerID: nil,
                currentScoreString: "0-0",
                endScoreString: "0-0",
                setsAndGamesOnly: "0-0"
            )
        }

        return ScoreEngine.compute(
            visiblePoints: Array(match.sortedPoints.prefix(cursor)),
            fullPoints: match.sortedPoints,
            p1: match.playerOne.id,
            p2: match.playerTwo.id,
            firstServerID: match.firstServerID
        )
    }

    var canBack: Bool {
        cursor > 0
    }

    var canForward: Bool {
        guard let match = match else { return false }
        return cursor < match.sortedPoints.count
    }

    func setMatch(_ newMatch: Match) {
        match = newMatch
        cursor = newMatch.sortedPoints.count
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