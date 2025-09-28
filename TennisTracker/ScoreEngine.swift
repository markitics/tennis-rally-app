//
//  ScoreEngine.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import Foundation

struct DerivedMatchState {
    let setScores: [(p1Games: Int, p2Games: Int)]
    let inGameDisplay: (p1: String, p2: String)
    let leaderID: UUID?
    let trailerID: UUID?
    let currentScoreString: String
    let endScoreString: String
}

enum ScoreEngine {

    static func compute(
        visiblePoints: [Point],
        fullPoints: [Point],
        p1: UUID,
        p2: UUID,
        firstServerID: UUID
    ) -> DerivedMatchState {

        let visibleState = foldPoints(points: visiblePoints, p1: p1, p2: p2)
        let fullState = foldPoints(points: fullPoints, p1: p1, p2: p2)

        let inGameDisplay = formatGameScore(raw: visibleState.currentGameScore, isTiebreak: visibleState.inTiebreak)

        let currentScoreString = buildScoreString(
            completedSets: visibleState.completedSets,
            currentSetGames: visibleState.currentSetGames,
            inGameDisplay: inGameDisplay,
            isTiebreak: visibleState.inTiebreak
        )

        let endScoreString = buildScoreString(
            completedSets: fullState.completedSets,
            currentSetGames: fullState.currentSetGames,
            inGameDisplay: ("0", "0"),
            isTiebreak: false
        )

        let (leaderID, trailerID) = determineLeader(
            completedSets: visibleState.completedSets,
            currentSetGames: visibleState.currentSetGames,
            currentGameScore: visibleState.currentGameScore,
            p1: p1,
            p2: p2
        )

        return DerivedMatchState(
            setScores: visibleState.completedSets.map { (p1Games: $0.p1, p2Games: $0.p2) },
            inGameDisplay: inGameDisplay,
            leaderID: leaderID,
            trailerID: trailerID,
            currentScoreString: currentScoreString,
            endScoreString: endScoreString
        )
    }

    static func currentSetNumber(from points: [Point], p1: UUID, p2: UUID) -> Int {
        let state = foldPoints(points: points, p1: p1, p2: p2)
        return state.completedSets.count + 1
    }

    static func currentServerID(
        visiblePoints: [Point],
        p1: UUID,
        p2: UUID,
        firstServerID: UUID
    ) -> UUID {
        let state = foldPoints(points: visiblePoints, p1: p1, p2: p2)

        if state.inTiebreak {
            let tiebreakPoints = state.currentGameScore.p1 + state.currentGameScore.p2
            let serverChanges = tiebreakPoints / 2
            return serverChanges % 2 == 0 ? firstServerID : (firstServerID == p1 ? p2 : p1)
        } else {
            // Server alternates every game - add completed sets games to current set games
            let totalCompletedGames = state.completedSets.reduce(0) { $0 + $1.p1 + $1.p2 }
            let currentSetGames = state.currentSetGames.p1 + state.currentSetGames.p2
            let totalGamesPlayed = totalCompletedGames + currentSetGames
            return totalGamesPlayed % 2 == 0 ? firstServerID : (firstServerID == p1 ? p2 : p1)
        }
    }
}

private extension ScoreEngine {

    struct MatchState {
        let completedSets: [(p1: Int, p2: Int)]
        let currentSetGames: (p1: Int, p2: Int)
        let currentGameScore: (p1: Int, p2: Int)
        let inTiebreak: Bool
    }

    static func foldPoints(points: [Point], p1: UUID, p2: UUID) -> MatchState {
        var completedSets: [(p1: Int, p2: Int)] = []
        var currentSetGames = (p1: 0, p2: 0)
        var currentGameScore = (p1: 0, p2: 0)
        var inTiebreak = false

        func addPoint(toPlayer: UUID) {
            if toPlayer == p1 {
                currentGameScore.p1 += 1
            } else {
                currentGameScore.p2 += 1
            }

            checkGameCompletion()
        }

        func checkGameCompletion() {
            let p1Score = currentGameScore.p1
            let p2Score = currentGameScore.p2

            var gameWon = false
            var winner: UUID?

            if inTiebreak {
                if (p1Score >= 7 && p1Score - p2Score >= 2) {
                    winner = p1
                    gameWon = true
                } else if (p2Score >= 7 && p2Score - p1Score >= 2) {
                    winner = p2
                    gameWon = true
                }
            } else {
                if (p1Score >= 4 && p1Score - p2Score >= 2) {
                    winner = p1
                    gameWon = true
                } else if (p2Score >= 4 && p2Score - p1Score >= 2) {
                    winner = p2
                    gameWon = true
                }
            }

            if gameWon, let winner = winner {
                currentGameScore = (p1: 0, p2: 0)

                if inTiebreak {
                    // Tiebreak winner gets 7, loser stays at 6
                    let finalSetScore = winner == p1 ? (p1: 7, p2: 6) : (p1: 6, p2: 7)
                    completedSets.append(finalSetScore)
                    currentSetGames = (p1: 0, p2: 0)
                    inTiebreak = false
                } else {
                    // Regular game won - increment games
                    if winner == p1 {
                        currentSetGames.p1 += 1
                    } else {
                        currentSetGames.p2 += 1
                    }
                    checkSetCompletion()
                }
            }
        }

        func checkSetCompletion() {
            let p1Games = currentSetGames.p1
            let p2Games = currentSetGames.p2

            if p1Games == 6 && p2Games == 6 {
                inTiebreak = true
            } else if (p1Games >= 6 && p1Games - p2Games >= 2) ||
                      (p2Games >= 6 && p2Games - p1Games >= 2) {
                completedSets.append((p1: p1Games, p2: p2Games))
                currentSetGames = (p1: 0, p2: 0)
            }
        }

        for point in points {
            addPoint(toPlayer: point.winner.id)
        }


        return MatchState(
            completedSets: completedSets,
            currentSetGames: currentSetGames,
            currentGameScore: currentGameScore,
            inTiebreak: inTiebreak
        )
    }

    static func formatGameScore(raw: (p1: Int, p2: Int), isTiebreak: Bool) -> (String, String) {
        let p1Score = raw.p1
        let p2Score = raw.p2

        // During tiebreaks, show integer points instead of tennis scoring
        if isTiebreak {
            return (String(p1Score), String(p2Score))
        }

        // Regular tennis game scoring
        let scoreMap = ["0", "15", "30", "40"]

        if p1Score >= 3 && p2Score >= 3 {
            if p1Score == p2Score {
                return ("Deuce", "")
            } else if p1Score > p2Score {
                return ("Ad", "40")
            } else {
                return ("40", "Ad")
            }
        }

        let p1Display = p1Score >= 4 ? "40" : scoreMap[p1Score]
        let p2Display = p2Score >= 4 ? "40" : scoreMap[p2Score]

        return (p1Display, p2Display)
    }

    static func buildScoreString(
        completedSets: [(p1: Int, p2: Int)],
        currentSetGames: (p1: Int, p2: Int),
        inGameDisplay: (String, String),
        isTiebreak: Bool
    ) -> String {
        var parts: [String] = []

        if !completedSets.isEmpty {
            let setsString = completedSets
                .map { "\($0.p1)-\($0.p2)" }
                .joined(separator: ", ")
            parts.append(setsString)
        }

        if currentSetGames.p1 > 0 || currentSetGames.p2 > 0 ||
           (inGameDisplay.0 != "0" || inGameDisplay.1 != "0") {
            parts.append("\(currentSetGames.p1)-\(currentSetGames.p2)")

            if isTiebreak {
                parts.append("(\(inGameDisplay.0)-\(inGameDisplay.1))")
            } else if inGameDisplay.0 != "0" || inGameDisplay.1 != "0" {
                parts.append("\(inGameDisplay.0)-\(inGameDisplay.1)")
            }
        }

        return parts.isEmpty ? "0-0" : parts.joined(separator: ", ")
    }

    static func determineLeader(
        completedSets: [(p1: Int, p2: Int)],
        currentSetGames: (p1: Int, p2: Int),
        currentGameScore: (p1: Int, p2: Int),
        p1: UUID,
        p2: UUID
    ) -> (leader: UUID?, trailer: UUID?) {

        let p1SetsWon = completedSets.filter { $0.p1 > $0.p2 }.count
        let p2SetsWon = completedSets.filter { $0.p2 > $0.p1 }.count

        if p1SetsWon != p2SetsWon {
            return p1SetsWon > p2SetsWon ? (p1, p2) : (p2, p1)
        }

        if currentSetGames.p1 != currentSetGames.p2 {
            return currentSetGames.p1 > currentSetGames.p2 ? (p1, p2) : (p2, p1)
        }

        if currentGameScore.p1 != currentGameScore.p2 {
            return currentGameScore.p1 > currentGameScore.p2 ? (p1, p2) : (p2, p1)
        }

        return (nil, nil)
    }
}