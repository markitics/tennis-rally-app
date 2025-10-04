//
//  PlayView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import ActivityKit
import UIKit
import AVFoundation

struct PlayView: View {
    @Environment(\.modelContext) private var modelContext

    let match: Match
    @ObservedObject var viewModel: MatchViewModel
    @ObservedObject var liveActivityManager: LiveActivityManager

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
                // Combined server indicator and current game score
                CombinedScoreHeaderView(
                    match: match,
                    derivedState: viewModel.derivedState,
                    currentServerID: currentServerID
                )

                // Completed sets and games display
                if !viewModel.derivedState.currentScoreString.isEmpty {
                    CompletedSetsView(derivedState: viewModel.derivedState)
                }

                // Point input buttons
                PointInputView(
                    match: match,
                    viewModel: viewModel,
                    currentServerID: currentServerID,
                    modelContext: modelContext,
                    liveActivityManager: liveActivityManager
                )
            }
            .padding()

            // Timeline navigation at bottom
            TimelineNavigationView(viewModel: viewModel)
                .padding(.top, 40)
                .padding(.bottom)
        }
    }


struct CombinedScoreHeaderView: View {
    let match: Match
    let derivedState: DerivedMatchState
    let currentServerID: UUID

    var body: some View {
        HStack {
            // Mark (left aligned)
            HStack(spacing: 8) {
                Circle()
                    .fill(currentServerID == match.playerOne.id ? Color.green : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary, lineWidth: 1)
                            .opacity(currentServerID == match.playerOne.id ? 0 : 1)
                    )

                Text(match.playerOne.name)
                    .font(.headline)
                    .fontWeight(currentServerID == match.playerOne.id ? .semibold : .medium)
            }

            Spacer()

            // Current game score (centered)
            Text("\(derivedState.inGameDisplay.0)-\(derivedState.inGameDisplay.1)")
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            Spacer()

            // Jeff (right aligned)
            HStack(spacing: 8) {
                Text(match.playerTwo.name)
                    .font(.headline)
                    .fontWeight(currentServerID == match.playerTwo.id ? .semibold : .medium)

                Circle()
                    .fill(currentServerID == match.playerTwo.id ? Color.green : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary, lineWidth: 1)
                            .opacity(currentServerID == match.playerTwo.id ? 0 : 1)
                    )
            }
        }
        .padding(.horizontal)
    }
}

struct CompletedSetsView: View {
    let derivedState: DerivedMatchState

    private var completedSetsAndGames: String {
        let fullScoreString = derivedState.currentScoreString
        let parts = fullScoreString.components(separatedBy: ", ")

        // If current game score is 0-0, the ScoreEngine might not include it in the string
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

        return baseString
    }

    var body: some View {
        if !completedSetsAndGames.isEmpty {
            Text(completedSetsAndGames)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                    GameProgressionView(match: match)
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
    @ObservedObject var liveActivityManager: LiveActivityManager

    @State private var isProcessingPoint = false
    @State private var lastPointTime: Date = Date()
    @AppStorage("soundEnabled") private var soundEnabled = true

    private let speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        // Unified context-aware 6-button layout (v4)
        UnifiedButtonsView(
            match: match,
            currentServerID: currentServerID,
            onPointRecorded: { player, type in
                recordPoint(player: player, type: type)
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordPointFromWidget"))) { notification in
            print("🔔 NOTIFICATION RECEIVED: onReceive triggered!")
            handleWidgetPointAction(notification)
        }
        .onAppear {
            print("📱 PointInputView appeared - notification listener is active")
        }
    }

    private func recordPoint(player: Player, type: PointType) {
        // Determine who wins the point to decide haptic pattern and sound
        let markWins: Bool
        switch type {
        case .doubleFault, .unforcedError:
            // Errors mean the opponent wins the point
            markWins = (player.id != match.playerOne.id)
        case .ace, .winner:
            // Winners and aces mean the player wins
            markWins = (player.id == match.playerOne.id)
        }

        // Determine the speech phrase based on player and point type
        let speechPhrase: String
        switch type {
        case .ace:
            speechPhrase = "\(player.name) ace"
        case .winner:
            speechPhrase = "\(player.name) winner"
        case .doubleFault:
            speechPhrase = "\(player.name) double fault"
        case .unforcedError:
            speechPhrase = "\(player.name) error"
        }

        // Haptic feedback and speech
        if markWins {
            // Mark won - short vibration
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        } else {
            // Jeff won - long vibration
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.prepare()
            impactFeedback.impactOccurred(intensity: 1.0)

            // Create a longer vibration effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let continueFeedback = UIImpactFeedbackGenerator(style: .medium)
                continueFeedback.prepare()
                continueFeedback.impactOccurred(intensity: 0.8)
            }
        }

        // Play speech (if enabled)
        if soundEnabled {
            let utterance = AVSpeechUtterance(string: speechPhrase)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.5 // Slightly faster than default
            speechSynthesizer.speak(utterance)
        }

        // Debounce rapid button presses to prevent crashes
        let now = Date()
        guard now.timeIntervalSince(lastPointTime) > 0.1 else { return } // 100ms minimum between points
        lastPointTime = now

        // Prevent multiple point processing
        guard !isProcessingPoint else { return }
        isProcessingPoint = true
        defer { isProcessingPoint = false }

        // Store score before adding this point to detect game completion
        let oldScore = viewModel.derivedState.currentScoreString

        // Determine who actually won the point based on the type
        let winner: Player
        let loser: Player

        switch type {
        case .doubleFault, .unforcedError:
            // Errors mean the opponent wins the point
            winner = (player.id == match.playerOne.id) ? match.playerTwo : match.playerOne
            loser = player
        case .ace, .winner:
            // Winners and aces mean the player wins
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

        // Check for game completion (when in-game score resets to 0-0)
        print("🎾 SCORE ANALYSIS: Old: '\(oldScore)' -> New: '\(newScore)'")

        let gameCompleted = didGameComplete(oldScore: oldScore, newScore: newScore)
        print("🎾 GAME COMPLETION CHECK: \(gameCompleted)")

        if gameCompleted {
            let isWinner = winner.name == match.playerOne.name && match.playerOne.name == "Mark" ||
                          winner.name == match.playerTwo.name && match.playerTwo.name == "Mark"

            let title = isWinner ? "🎉 Great Job!" : "🎾 Stay Focused!"
            let body = isWinner ? "You won that game! \(newScore)" : "Keep pushing! \(newScore)"

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to send game completion notification: \(error)")
                } else {
                    print("🔔 Game completion notification sent: \(title)")
                }
            }
        }

        // Update Live Activity with new score
        if #available(iOS 16.1, *) {
            let serverName = currentServerID == match.playerOne.id ? match.playerOne.name : match.playerTwo.name
            liveActivityManager.updateMatchActivity(
                currentScore: newScore,
                serverName: serverName
            )
        }
    }

    private func didGameComplete(oldScore: String, newScore: String) -> Bool {
        // Game completes when in-game score resets to 0-0 (new game starts)
        // This happens when someone wins a game and the next game begins

        // Check if old score had an in-game component that wasn't 0-0
        // and new score shows 0-0 (meaning game just completed)

        let oldInGame = getInGameScore(from: oldScore)
        let newInGame = getInGameScore(from: newScore)

        print("🎾 GAME COMPLETION DEBUG: oldInGame='\(oldInGame)', newInGame='\(newInGame)'")

        // Game completed if we went from some in-game score to 0-0
        let completed = oldInGame != "0-0" && newInGame == "0-0"
        print("🎾 GAME COMPLETION RESULT: \(completed)")

        return completed
    }

    private func getInGameScore(from score: String) -> String {
        // Extract in-game score like "15-30" from "6-3, 2-1, 15-30"
        // Or "0-0" if no in-game score exists

        let parts = score.components(separatedBy: ", ")

        if parts.count <= 2 {
            // Either "1-2" (no in-game) or "6-3, 2-1" (no in-game)
            return "0-0"
        } else {
            // "6-3, 2-1, 15-30" -> return "15-30"
            return parts.last ?? "0-0"
        }
    }

    private func getGamesComponent(from parts: [String]) -> String {
        // Score format examples:
        // "1-2" -> games component is "1-2"
        // "6-3, 2-1" -> games component is "2-1"
        // "6-6 (3-2)" -> games component is "6-6"

        if parts.count == 1 {
            // Single component like "1-2" - this is the games
            return parts[0]
        } else if parts.count == 2 {
            // Two components like "6-3, 2-1" - second is current set games
            return parts[1]
        } else {
            // Multiple sets like "6-3, 6-4, 2-1" - last is current set games
            return parts.last ?? ""
        }
    }

    // Handle point recording from Live Activity buttons
    private func handleWidgetPointAction(_ notification: Notification) {
        let timestamp = Date()
        print("🎯 WIDGET ACTION HANDLER [\(timestamp)]: Function called!")
        print("🎯 WIDGET ACTION HANDLER: Notification name: '\(notification.name)'")
        print("🎯 WIDGET ACTION HANDLER: Notification object: \(notification.object ?? "nil")")
        print("🎯 WIDGET ACTION HANDLER: UserInfo: \(notification.userInfo ?? [:])")

        guard let userInfo = notification.userInfo,
              let pointTypeString = userInfo["pointType"] as? String,
              let playerName = userInfo["player"] as? String else {
            print("❌ Invalid widget action notification")
            print("❌ userInfo exists: \(notification.userInfo != nil)")
            print("❌ pointType: '\(notification.userInfo?["pointType"] ?? "nil")'")
            print("❌ player: '\(notification.userInfo?["player"] ?? "nil")'")
            return
        }

        print("🎯 WIDGET ACTION: \(pointTypeString) for \(playerName)")

        // Convert string to PointType
        let pointType: PointType
        switch pointTypeString {
        case "winner":
            pointType = .winner
            print("🎯 Converted to: .winner")
        case "ace":
            pointType = .ace
            print("🎯 Converted to: .ace")
        case "unforcedError":
            pointType = .unforcedError
            print("🎯 Converted to: .unforcedError")
        default:
            print("❌ Unknown point type: \(pointTypeString)")
            return
        }

        // Find the player
        let player: Player
        print("🎯 Looking for player '\(playerName)'")
        print("🎯 Available players: '\(match.playerOne.name)' vs '\(match.playerTwo.name)'")

        if playerName == match.playerOne.name {
            player = match.playerOne
            print("🎯 Found player: \(match.playerOne.name) (Player One)")
        } else if playerName == match.playerTwo.name {
            player = match.playerTwo
            print("🎯 Found player: \(match.playerTwo.name) (Player Two)")
        } else {
            print("❌ Unknown player: '\(playerName)'")
            print("❌ Expected: '\(match.playerOne.name)' or '\(match.playerTwo.name)'")
            return
        }

        print("🎯 RECORDING POINT: \(pointType.rawValue) for \(player.name)")
        print("🎯 About to call recordPoint...")

        // Record the point using existing logic
        recordPoint(player: player, type: pointType)

        print("🎯 ✅ recordPoint completed [\(timestamp)]")
    }
}

struct UnifiedButtonsView: View {
    let match: Match
    let currentServerID: UUID
    let onPointRecorded: (Player, PointType) -> Void

    private var server: Player {
        currentServerID == match.playerOne.id ? match.playerOne : match.playerTwo
    }

    private var receiver: Player {
        currentServerID == match.playerOne.id ? match.playerTwo : match.playerOne
    }

    var body: some View {
        VStack(spacing: 24) {

            VStack(spacing: 24) {
                // Column headers
                HStack {
                    Spacer()
                    Text("Mark wins point 👇")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                    Spacer()
                    Text("Jeff wins point 👇")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)

                // Row 1: Serve
                HStack(alignment: .center, spacing: 4) {
                    Text("Serve")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 30, alignment: .leading)

                    HStack(spacing: 16) {
                        if server.name == "Mark" {
                            PointButton("🎾 Mark ace", color: Color(white: 0.3), height: 50) {
                                onPointRecorded(match.playerOne, .ace)
                            }
                        } else {
                            // Jeff is serving, so Jeff double fault = Mark wins point (left column)
                            PointButton("❌ Double fault", color: Color(white: 0.3), height: 50) {
                                onPointRecorded(match.playerTwo, .doubleFault)
                            }
                        }

                        if server.name == "Jeff" {
                            PointButton("🎾 Jeff ace", color: .gray, height: 50) {
                                onPointRecorded(match.playerTwo, .ace)
                            }
                        } else {
                            // Mark is serving, so Mark double fault = Jeff wins point (right column)
                            PointButton("❌ Double fault", color: .gray, height: 50) {
                                onPointRecorded(match.playerOne, .doubleFault)
                            }
                        }
                    }
                }

                // Row 2: Rally
                HStack(alignment: .center, spacing: 4) {
                    Text("Rally")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 30, alignment: .leading)

                    HStack(spacing: 20) {
                        PointButton("🚀 Mark rally winner", color: Color(white: 0.3), height: 90) {
                            onPointRecorded(match.playerOne, .winner)
                        }

                        PointButton("🚀 Jeff rally winner", color: .gray, height: 90) {
                            onPointRecorded(match.playerTwo, .winner)
                        }
                    }
                }

                // Row 3: Rally errors
                HStack(alignment: .center, spacing: 4) {
                    Text("")
                        .frame(width: 30)

                    HStack(spacing: 20) {
                        // Left column = Mark wins point = Jeff makes unforced error
                        PointButton("🙈 Jeff error", color: Color(white: 0.3), height: 100) {
                            onPointRecorded(match.playerTwo, .unforcedError)
                        }

                        // Right column = Jeff wins point = Mark makes unforced error
                        PointButton("🙈 Mark  error", color: .gray, height: 100) {
                            onPointRecorded(match.playerOne, .unforcedError)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical)
    }
}

// Keep the old PlayerButtonsView as a fallback (can remove later)
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
                if isServer {
                    PointButton("🎾 Ace", color: .yellow) {
                        onPointRecorded(.ace)
                    }

                    PointButton("❌ Double Fault", color: .red) {
                        onPointRecorded(.doubleFault)
                    }
                } else {
                    PointButton("🏆 Winner", color: .teal) {
                        onPointRecorded(.winner)
                    }

                    PointButton("🙈 Unforced Error", color: .pink) {
                        onPointRecorded(.unforcedError)
                    }
                }
            }
        }
    }
}

enum PointButtonStyle {
    case prominent
    case secondary
}

struct PointButton: View {
    let title: String
    let color: Color
    let style: PointButtonStyle
    let disabled: Bool
    let height: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    init(_ title: String, color: Color = .blue, style: PointButtonStyle = .prominent, height: CGFloat = 50, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.style = style
        self.height = height
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color == .gray ? .black : .white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(disabled ? Color.gray.opacity(0.4) : (isPressed ? color.opacity(0.8) : color))
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

struct GameProgressionView: View {
    let match: Match

    private func pointsToTennisScore(_ p1Points: Int, _ p2Points: Int) -> (String, String) {
        // Handle deuce scenarios
        if p1Points >= 3 && p2Points >= 3 {
            if p1Points == p2Points {
                return ("40", "40") // Deuce
            } else if p1Points > p2Points {
                return ("Ad", "40")
            } else {
                return ("40", "Ad")
            }
        }

        // Normal scoring
        func scoreValue(_ points: Int) -> String {
            switch points {
            case 0: return "0"
            case 1: return "15"
            case 2: return "30"
            default: return "40"
            }
        }

        return (scoreValue(p1Points), scoreValue(p2Points))
    }

    private func describePoint(_ point: Point) -> String {
        switch point.type {
        case .ace:
            return "\(point.winner.name) ace"
        case .winner:
            return "\(point.winner.name) winner"
        case .doubleFault:
            return "\(point.loser.name) double fault"
        case .unforcedError:
            return "\(point.loser.name) error"
        }
    }

    // Find the points for the current game
    private var currentGamePoints: [Point] {
        guard !match.sortedPoints.isEmpty else { return [] }

        // Split points into games by walking forward and detecting game boundaries
        var allGames: [[Point]] = []
        var currentGame: [Point] = []
        var p1GameScore = 0
        var p2GameScore = 0

        for point in match.sortedPoints {
            currentGame.append(point)

            // Count points in current game
            if point.winner.id == match.playerOne.id {
                p1GameScore += 1
            } else {
                p2GameScore += 1
            }

            // Check if game is won
            let gameWon = (p1GameScore >= 4 || p2GameScore >= 4) && abs(p1GameScore - p2GameScore) >= 2
            if gameWon {
                // Game complete, save it and start new game
                allGames.append(currentGame)
                currentGame = []
                p1GameScore = 0
                p2GameScore = 0
            }
        }

        // Return the current incomplete game (if any points exist)
        return currentGame
    }

    // Find the points for the last completed game
    private var lastCompletedGamePoints: [Point] {
        guard !match.sortedPoints.isEmpty else { return [] }

        // Split points into games by walking forward and detecting game boundaries
        var allGames: [[Point]] = []
        var currentGame: [Point] = []
        var p1GameScore = 0
        var p2GameScore = 0

        for point in match.sortedPoints {
            currentGame.append(point)

            // Count points in current game
            if point.winner.id == match.playerOne.id {
                p1GameScore += 1
            } else {
                p2GameScore += 1
            }

            // Check if game is won
            let gameWon = (p1GameScore >= 4 || p2GameScore >= 4) && abs(p1GameScore - p2GameScore) >= 2
            if gameWon {
                // Game complete, save it and start new game
                allGames.append(currentGame)
                currentGame = []
                p1GameScore = 0
                p2GameScore = 0
            }
        }

        // Return the last completed game (if any)
        return allGames.last ?? []
    }

    private func buildProgression(from points: [Point]) -> String {
        guard !points.isEmpty else { return "" }

        var progression = "0-0"
        var p1Score = 0
        var p2Score = 0

        for point in points {
            // Update point counts
            if point.winner.id == match.playerOne.id {
                p1Score += 1
            } else {
                p2Score += 1
            }

            // Build progression string
            let action = describePoint(point)
            let (p1Display, p2Display) = pointsToTennisScore(p1Score, p2Score)
            let newScore = "\(p1Display)-\(p2Display)"
            progression += " → \(action) → \(newScore)"

            // Check if game is won
            let gameWon = (p1Score >= 4 || p2Score >= 4) && abs(p1Score - p2Score) >= 2
            if gameWon {
                progression += " (Game)"
            }
        }

        return progression
    }

    private var isCurrentScoreZeroZero: Bool {
        let currentPoints = currentGamePoints
        return currentPoints.isEmpty
    }

    private var isFirstGameOfMatch: Bool {
        // If we have no completed games and current game is at 0-0
        return lastCompletedGamePoints.isEmpty && currentGamePoints.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if match.sortedPoints.isEmpty {
                    Text("Match just started")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if isCurrentScoreZeroZero && !isFirstGameOfMatch {
                    // Show last completed game
                    Text("Last game finished:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(buildProgression(from: lastCompletedGamePoints))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                } else if !currentGamePoints.isEmpty {
                    // Show current game in progress
                    Text("Recent progression:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(buildProgression(from: currentGamePoints))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                } else {
                    // First game at 0-0
                    Text("Ready to start first game")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxHeight: 150)
    }
}
}
