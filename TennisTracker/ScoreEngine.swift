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
    let setsAndGamesOnly: String // Score without in-game (e.g., "6-4, 3-2")
    let inTiebreak: Bool
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

        // Build sets/games only score (no in-game score)
        let setsAndGamesOnly = buildScoreString(
            completedSets: visibleState.completedSets,
            currentSetGames: visibleState.currentSetGames,
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
            endScoreString: endScoreString,
            setsAndGamesOnly: setsAndGamesOnly,
            inTiebreak: visibleState.inTiebreak
        )
    }

    static func currentSetNumber(from points: [Point], p1: UUID, p2: UUID) -> Int {
        let state = foldPoints(points: points, p1: p1, p2: p2)
        return state.completedSets.count + 1
    }

    static func currentGameNumber(from points: [Point], p1: UUID, p2: UUID) -> Int {
        guard !points.isEmpty else { return 1 }

        var gamesCompleted = 0
        var currentGameScore = (p1: 0, p2: 0)
        var inTiebreak = false
        var currentSetGames = (p1: 0, p2: 0)

        for point in points {
            // Add point to current game
            if point.winner.id == p1 {
                currentGameScore.p1 += 1
            } else {
                currentGameScore.p2 += 1
            }

            // Check if game is complete
            let gameWon: Bool
            if inTiebreak {
                gameWon = (currentGameScore.p1 >= 7 && currentGameScore.p1 - currentGameScore.p2 >= 2) ||
                         (currentGameScore.p2 >= 7 && currentGameScore.p2 - currentGameScore.p1 >= 2)
            } else {
                gameWon = (currentGameScore.p1 >= 4 && currentGameScore.p1 - currentGameScore.p2 >= 2) ||
                         (currentGameScore.p2 >= 4 && currentGameScore.p2 - currentGameScore.p1 >= 2)
            }

            if gameWon {
                gamesCompleted += 1
                currentGameScore = (p1: 0, p2: 0)

                // Update set games for tiebreak detection
                if inTiebreak {
                    inTiebreak = false
                    currentSetGames = (p1: 0, p2: 0) // Set complete
                } else {
                    if point.winner.id == p1 {
                        currentSetGames.p1 += 1
                    } else {
                        currentSetGames.p2 += 1
                    }

                    // Check for tiebreak or set completion
                    if currentSetGames.p1 == 6 && currentSetGames.p2 == 6 {
                        inTiebreak = true
                    } else if (currentSetGames.p1 >= 6 && currentSetGames.p1 - currentSetGames.p2 >= 2) ||
                              (currentSetGames.p2 >= 6 && currentSetGames.p2 - currentSetGames.p1 >= 2) {
                        currentSetGames = (p1: 0, p2: 0) // Set complete
                    }
                }
            }
        }

        return gamesCompleted + 1
    }

    // Helper to detect if we just entered a tiebreak and who should serve first
    static func checkForTiebreakStart(
        oldPoints: [Point],
        newPoints: [Point],
        p1: UUID,
        p2: UUID,
        firstServerID: UUID,
        currentTiebreakFirstServers: [UUID]
    ) -> [UUID] {
        let oldState = foldPoints(points: oldPoints, p1: p1, p2: p2)
        let newState = foldPoints(points: newPoints, p1: p1, p2: p2)

        // Check if we just entered a new tiebreak
        if !oldState.inTiebreak && newState.inTiebreak {
            let currentSetNumber = newState.completedSets.count + 1

            // Only record if we don't already have this tiebreak recorded
            if currentSetNumber > currentTiebreakFirstServers.count {
                // Calculate who serves first in tiebreak (whoever would serve the NEXT game)
                let totalCompletedGames = oldState.completedSets.reduce(0) { $0 + $1.p1 + $1.p2 }
                let currentSetGames = oldState.currentSetGames.p1 + oldState.currentSetGames.p2
                let totalGamesPlayed = totalCompletedGames + currentSetGames
                // Add 1 because we want who would serve game 13 (the next game after 6-6)
                let tiebreakFirstServer = (totalGamesPlayed + 1) % 2 == 0 ? firstServerID : (firstServerID == p1 ? p2 : p1)

                var updatedServers = currentTiebreakFirstServers
                updatedServers.append(tiebreakFirstServer)
                return updatedServers
            }
        }

        return currentTiebreakFirstServers
    }

    static func currentServerID(
        visiblePoints: [Point],
        p1: UUID,
        p2: UUID,
        firstServerID: UUID,
        tiebreakFirstServers: [UUID] = []
    ) -> UUID {
        let state = foldPoints(points: visiblePoints, p1: p1, p2: p2)

        if state.inTiebreak {
            let tiebreakPoints = state.currentGameScore.p1 + state.currentGameScore.p2

            // Determine who serves first in this tiebreak
            let currentSetNumber = state.completedSets.count + 1
            let tiebreakFirstServer: UUID

            if currentSetNumber <= tiebreakFirstServers.count {
                // Use stored tiebreak first server
                tiebreakFirstServer = tiebreakFirstServers[currentSetNumber - 1]
            } else {
                // Calculate who should serve first in tiebreak (normal alternation)
                let totalCompletedGames = state.completedSets.reduce(0) { $0 + $1.p1 + $1.p2 }
                let currentSetGames = state.currentSetGames.p1 + state.currentSetGames.p2
                let totalGamesPlayed = totalCompletedGames + currentSetGames
                tiebreakFirstServer = totalGamesPlayed % 2 == 0 ? firstServerID : (firstServerID == p1 ? p2 : p1)
            }

            // Tennis rule: first server serves 1 point, then alternate every 2 points
            let serverChanges = (tiebreakPoints + 1) / 2
            return serverChanges % 2 == 0 ? tiebreakFirstServer : (tiebreakFirstServer == p1 ? p2 : p1)
        } else {
            // Server alternates every game, but account for tiebreak-to-next-set rule
            let totalCompletedGames = state.completedSets.reduce(0) { $0 + $1.p1 + $1.p2 }
            let currentSetGames = state.currentSetGames.p1 + state.currentSetGames.p2

            // If we're starting a new set after a tiebreak, apply the official rule
            if currentSetGames == 0 && state.completedSets.count > 0 {
                // Check if the previous set was won by tiebreak (7-6 or 6-7)
                let lastSet = state.completedSets.last!
                if (lastSet.p1 == 7 && lastSet.p2 == 6) || (lastSet.p1 == 6 && lastSet.p2 == 7) {
                    // Previous set had tiebreak - receiver of first tiebreak point serves first
                    let tiebreakIndex = state.completedSets.count - 1
                    if tiebreakIndex < tiebreakFirstServers.count {
                        let tiebreakFirstServer = tiebreakFirstServers[tiebreakIndex]
                        // Return the opponent of who served first in tiebreak
                        return tiebreakFirstServer == p1 ? p2 : p1
                    }
                }
            }

            // Normal alternation based on total games played
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

        // Handle deuce and advantage situations (both players at 3+ points)
        if p1Score >= 3 && p2Score >= 3 {
            if p1Score == p2Score {
                return ("Deuce", "")
            } else if p1Score > p2Score {
                return ("Ad", "40")
            } else {
                return ("40", "Ad")
            }
        }

        // Normal scoring - cap at 40 (index 3)
        let p1Display = p1Score >= 3 ? "40" : scoreMap[p1Score]
        let p2Display = p2Score >= 3 ? "40" : scoreMap[p2Score]

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