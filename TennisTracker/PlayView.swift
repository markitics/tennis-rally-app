//
//  PlayView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData

struct PlayView: View {
    @Environment(\.modelContext) private var modelContext

    let match: Match
    @ObservedObject var viewModel: MatchViewModel

    private var currentServerID: UUID {
        ScoreEngine.currentServerID(
            visiblePoints: Array(match.sortedPoints.prefix(viewModel.cursor)),
            p1: match.playerOne.id,
            p2: match.playerTwo.id,
            firstServerID: match.firstServerID,
            tiebreakFirstServers: match.tiebreakFirstServers
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Player names with server indicator
                HStack(spacing: 30) {
                    PlayerHeaderView(
                        player: match.playerOne,
                        isServing: currentServerID == match.playerOne.id
                    )

                    PlayerHeaderView(
                        player: match.playerTwo,
                        isServing: currentServerID == match.playerTwo.id
                    )
                }
                .padding(.top)

                // Score display
                ScoreDisplayView(match: match, derivedState: viewModel.derivedState)

                // Point input buttons
                PointInputView(
                    match: match,
                    viewModel: viewModel,
                    currentServerID: currentServerID,
                    modelContext: modelContext
                )
            }
            .padding()

            // Timeline navigation at bottom
            TimelineNavigationView(viewModel: viewModel)
                .padding(.top, 40)
                .padding(.bottom)
        }
    }
}

struct PlayerHeaderView: View {
    let player: Player
    let isServing: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isServing ? Color.green : Color.clear)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.secondary, lineWidth: 1)
                        .opacity(isServing ? 0 : 1)
                )

            Text(player.name)
                .font(.headline)
                .fontWeight(isServing ? .semibold : .medium)
        }
    }
}

struct ScoreDisplayView: View {
    let match: Match
    let derivedState: DerivedMatchState

    private var completedSetsAndGames: String {
        let fullScoreString = derivedState.currentScoreString
        let parts = fullScoreString.components(separatedBy: ", ")

        // If current game score is 0-0, the ScoreEngine might not include it in the string
        // So we need to check if the in-game display is 0-0
        let currentGameIs00 = derivedState.inGameDisplay.0 == "0" && derivedState.inGameDisplay.1 == "0"

        let baseString: String
        if currentGameIs00 {
            // When game is 0-0, the full string IS the completed games/sets
            baseString = fullScoreString.isEmpty ? "" : fullScoreString
        } else {
            // When game is not 0-0, drop the last component (which is the in-game score)
            if parts.count <= 1 {
                baseString = ""
            } else {
                baseString = parts.dropLast().joined(separator: ", ")
            }
        }

        // Add winning indicator if there's any score to show
        if !baseString.isEmpty, let leaderID = derivedState.leaderID {
            let winnerName = leaderID == match.playerOne.id ? match.playerOne.name : match.playerTwo.name
            return "\(baseString)\n(\(winnerName) winning)"
        }

        return baseString
    }

    private var currentGameScore: String {
        // Return the in-game display (15-30, Deuce, etc.)
        let p1Score = derivedState.inGameDisplay.0
        let p2Score = derivedState.inGameDisplay.1

        // Handle Deuce case - show just "Deuce" instead of "Deuce-"
        if p1Score == "Deuce" && p2Score.isEmpty {
            return "Deuce"
        }

        return "\(p1Score)-\(p2Score)"
    }

    var body: some View {
        HStack {
            // Left side: Completed sets and current set games
            Text(completedSetsAndGames.isEmpty ? "" : completedSetsAndGames)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Right side: Current game score
            Text(currentGameScore)
                .font(.largeTitle)
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
}

struct TimelineNavigationView: View {
    @ObservedObject var viewModel: MatchViewModel
    @State private var backPressed = false
    @State private var forwardPressed = false

    var body: some View {
        HStack(spacing: 20) {
            Button(action: animatedBack) {
                Label("Back", systemImage: "arrow.left")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canBack)
            .scaleEffect(backPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: backPressed)

            VStack(spacing: 2) {
                Text("\(viewModel.cursor)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                // Debug indicator - only show bug if cursor is out of sync AND we're not intentionally navigating
                if let match = viewModel.match,
                   viewModel.cursor != match.sortedPoints.count &&
                   !viewModel.canForward {
                    Text("🐛")
                        .font(.caption2)
                }

                // Show up to last 50 button presses for debugging
                if let match = viewModel.match {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(match.sortedPoints.suffix(50).reversed(), id: \.id) { point in
                                Text("Pt\(match.sortedPoints.firstIndex(where: { $0.id == point.id })! + 1): \(point.winner.name) via \(point.type.rawValue)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            Button(action: animatedForward) {
                Label("Forward", systemImage: "arrow.right")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canForward)
            .scaleEffect(forwardPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: forwardPressed)
        }
    }

    private func animatedBack() {
        guard viewModel.canBack else { return }

        backPressed = true
        viewModel.back()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            backPressed = false
        }
    }

    private func animatedForward() {
        guard viewModel.canForward else { return }

        forwardPressed = true
        viewModel.forward()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            forwardPressed = false
        }
    }
}

struct PointInputView: View {
    let match: Match
    @ObservedObject var viewModel: MatchViewModel
    let currentServerID: UUID
    let modelContext: ModelContext

    @State private var isProcessingPoint = false
    @State private var lastPointTime: Date = Date()

    var body: some View {
        VStack(spacing: 24) {
            PlayerButtonsView(
                player: match.playerOne,
                isServer: currentServerID == match.playerOne.id,
                onPointRecorded: { type in
                    recordPoint(player: match.playerOne, type: type)
                }
            )

            Divider()

            PlayerButtonsView(
                player: match.playerTwo,
                isServer: currentServerID == match.playerTwo.id,
                onPointRecorded: { type in
                    recordPoint(player: match.playerTwo, type: type)
                }
            )
        }
    }

    private func recordPoint(player: Player, type: PointType) {
        // Debounce rapid button presses to prevent crashes
        let now = Date()
        guard now.timeIntervalSince(lastPointTime) > 0.1 else { return } // 100ms minimum between points
        lastPointTime = now

        // Prevent multiple point processing
        guard !isProcessingPoint else { return }
        isProcessingPoint = true
        defer { isProcessingPoint = false }

        // Determine who actually won the point based on the type
        let winner: Player
        let loser: Player

        switch type {
        case .doubleFault, .unforcedError:
            // Errors mean the opponent wins the point
            winner = (player.id == match.playerOne.id) ? match.playerTwo : match.playerOne
            loser = player
        case .dropShotWinner, .otherWinner, .unknown:
            // Winners and unknown points mean the player wins
            winner = player
            loser = (player.id == match.playerOne.id) ? match.playerTwo : match.playerOne
        }

        // Fix cursor sync issues from rapid tapping, but preserve rewrite-from-here functionality
        let expectedCursor = match.sortedPoints.count

        // If cursor is ahead of points count, it's a race condition - fix it
        if viewModel.cursor > expectedCursor {
            viewModel.cursor = expectedCursor
        }

        // Implement rewrite-from-here logic (restored!)
        if viewModel.cursor < match.sortedPoints.count {
            // Remove points from cursor position onwards - need to work with original array
            let sortedPoints = match.sortedPoints
            let pointsToRemove = sortedPoints[viewModel.cursor...]
            for pointToRemove in pointsToRemove {
                match.points.removeAll { $0.id == pointToRemove.id }
            }
        }

        let setNumber = ScoreEngine.currentSetNumber(
            from: Array(match.sortedPoints.prefix(viewModel.cursor)),
            p1: match.playerOne.id,
            p2: match.playerTwo.id
        )

        let newPoint = Point(
            match: match,
            winner: winner,
            loser: loser,
            type: type,
            setNumber: setNumber
        )

        // Store old points for tiebreak detection
        let oldPoints = match.sortedPoints

        // Add point using proper SwiftData relationship
        modelContext.insert(newPoint)
        viewModel.cursor = match.sortedPoints.count

        // Check if we just started a new tiebreak and update tiebreak first servers
        let updatedTiebreakFirstServers = ScoreEngine.checkForTiebreakStart(
            oldPoints: oldPoints,
            newPoints: match.sortedPoints,
            p1: match.playerOne.id,
            p2: match.playerTwo.id,
            firstServerID: match.firstServerID,
            currentTiebreakFirstServers: match.tiebreakFirstServers
        )

        if updatedTiebreakFirstServers.count > match.tiebreakFirstServers.count {
            let tiebreakFirstServer = updatedTiebreakFirstServers.last!
            let serverName = tiebreakFirstServer == match.playerOne.id ? match.playerOne.name : match.playerTwo.name
            print("🎾 TIEBREAK STARTED: \(serverName) serves first in tiebreak")
        }

        match.tiebreakFirstServers = updatedTiebreakFirstServers

        // DEBUG: Log for each button press
        let buttonPressed = "\(player.name)'s \(type.rawValue)"
        let totalPoints = match.sortedPoints.count
        let pointWonBy = winner.name
        let newScore = viewModel.derivedState.currentScoreString

        print("Button pressed: \(buttonPressed) | Total points played: \(totalPoints) | This point won by: \(pointWonBy) | New overall score: \(newScore)")

        // DEBUG: Log the last few points to see what ScoreEngine is processing
        let recentPoints = match.sortedPoints.suffix(5)
        print("Recent points: \(recentPoints.map { "\($0.winner.name):\($0.type.rawValue)" }.joined(separator: ", "))")

        // DEBUG: Log ALL points to verify chronological order
        print("ALL POINTS (\(match.sortedPoints.count)): \(match.sortedPoints.map { "\($0.winner.name):\($0.type.rawValue)" }.joined(separator: ", "))")
    }
}

struct PlayerButtonsView: View {
    let player: Player
    let isServer: Bool
    let onPointRecorded: (PointType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(player.name)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 24) {
                PointButton("🏆 Drop Shot Winner", color: .teal) {
                    onPointRecorded(.dropShotWinner)
                }

                PointButton("🚀 Other Winner", color: .mint) {
                    onPointRecorded(.otherWinner)
                }

                if isServer {
                    PointButton("❌ Double Fault", color: .red) {
                        onPointRecorded(.doubleFault)
                    }
                } else {
                    // Empty space to maintain grid alignment
                    Color.clear
                }

                PointButton("🙈 Unforced Error", color: .pink) {
                    onPointRecorded(.unforcedError)
                }
            }

            PointButton("🤔 Unknown Won", color: .gray) {
                onPointRecorded(.unknown)
            }
        }
    }
}

struct PointButton: View {
    let title: String
    let color: Color
    let disabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(_ title: String, color: Color = .blue, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(disabled ? Color.gray.opacity(0.4) : (isPressed ? color.opacity(0.7) : color))
                .shadow(color: isPressed ? .clear : color.opacity(0.3), radius: isPressed ? 0 : 4, x: 0, y: isPressed ? 0 : 2)
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .disabled(disabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !disabled && !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, Match.self, Point.self, configurations: config)

    let player1 = Player(name: "You")
    let player2 = Player(name: "Opponent")
    let match = Match(playerOne: player1, playerTwo: player2, firstServerID: player1.id)

    return PlayView(match: match, viewModel: MatchViewModel())
    .modelContainer(container)
}