//
//  ContentView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case play = "Play"
        case view = "View"
        case settings = "Settings"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.matchDate, order: .reverse) private var matches: [Match]

    private var activeMatch: Match? {
        matches.first { !$0.isCompleted }
    }

    private var hasCompletedMatches: Bool {
        matches.contains { $0.isCompleted }
    }

    @State private var selectedTab: Tab = .play
    @State private var selectedMatch: Match?
    @State private var showingFirstServerSelection = false
    @StateObject private var matchViewModel = MatchViewModel()
    @StateObject private var liveActivityManager: LiveActivityManager = {
        if #available(iOS 16.1, *) {
            return LiveActivityManager()
        } else {
            return LiveActivityManager()
        }
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Main content area
                VStack {
                    switch selectedTab {
                    case .play:
                        if let match = activeMatch {
                            PlayView(match: match, viewModel: matchViewModel, liveActivityManager: liveActivityManager)
                        } else if showingFirstServerSelection {
                            FirstServerSelectionView(
                                player1: matches.first?.playerOne ?? Player(name: "Mark"),
                                player2: matches.first?.playerTwo ?? Player(name: "Jeff")
                            ) {
                                createNewMatch(firstServer: $0)
                            }
                        } else {
                            EmptyStateView(hasCompletedMatches: hasCompletedMatches) {
                                // Always show first server selection for new matches
                                showingFirstServerSelection = true
                            }
                        }
                    case .view:
                        StatsView(matches: matches, selectedMatch: $selectedMatch)
                    case .settings:
                        SettingsView()
                            .environmentObject(liveActivityManager)
                            .environmentObject(matchViewModel)
                    }

                    Spacer()
                }
                .animation(.default, value: selectedTab)
            }
            .task {
                ensureMatchSelection()
            }
            .onChange(of: matches) {
                ensureMatchSelection()
            }
            .onChange(of: activeMatch) { oldValue, newValue in
                if let match = newValue {
                    matchViewModel.setMatch(match)
                }
            }
        }
    }

    private func ensureMatchSelection() {
        if selectedMatch == nil && !matches.isEmpty {
            selectedMatch = matches.first
        }
        if let match = activeMatch {
            matchViewModel.setMatch(match)
        }
    }

    private func createSampleMatch() {
        let player1 = Player(name: "Mark")
        let player2 = Player(name: "Jeff")

        modelContext.insert(player1)
        modelContext.insert(player2)

        let match = Match(
            playerOne: player1,
            playerTwo: player2,
            firstServerID: player1.id
        )

        modelContext.insert(match)
        selectedMatch = match
    }


    private func createNewMatch(firstServer: Player) {
        print("🎾 DEBUG: createNewMatch called with server: \(firstServer.name)")
        let player1: Player
        let player2: Player

        if let lastMatch = matches.first {
            // Use players from last match
            player1 = lastMatch.playerOne
            player2 = lastMatch.playerTwo
        } else {
            // First match ever - create default players
            player1 = Player(name: "Mark")
            player2 = Player(name: "Jeff")
            modelContext.insert(player1)
            modelContext.insert(player2)
        }

        // Map the selected firstServer to the actual player we're using
        let actualFirstServerID = firstServer.name == player1.name ? player1.id : player2.id

        let newMatch = Match(
            playerOne: player1,
            playerTwo: player2,
            firstServerID: actualFirstServerID
        )

        modelContext.insert(newMatch)
        selectedMatch = newMatch  // Auto-select the new match in View tab
        showingFirstServerSelection = false

        // Send immediate test notification
        let content = UNMutableNotificationContent()
        content.title = "🎾 Match Started!"
        content.body = "New match: \(firstServer.name) serving first"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send match start notification: \(error)")
            } else {
                print("🔔 Match start notification sent successfully")
            }
        }

        // Start Live Activity for the new match
        if #available(iOS 16.1, *) {
            let serverName = firstServer.name
            print("🎾 About to start Live Activity for new match")

            // Compute initial derived state (0-0 at start)
            let initialState = ScoreEngine.compute(
                visiblePoints: [],
                fullPoints: [],
                p1: newMatch.playerOne.id,
                p2: newMatch.playerTwo.id,
                firstServerID: newMatch.firstServerID
            )

            liveActivityManager.startMatchActivity(
                match: newMatch,
                serverName: serverName,
                derivedState: initialState
            )
        }
    }
}

struct EmptyStateView: View {
    let hasCompletedMatches: Bool
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if hasCompletedMatches {
                Text("No Active Match")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You can start a new match or view completed matches in the View tab.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text("Welcome to Tennis Tracker")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start tracking your tennis matches with precise point-by-point scoring.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button("Start New Match") {
                createAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct FirstServerSelectionView: View {
    let player1: Player
    let player2: Player
    let onPlayerSelected: (Player) -> Void

    @State private var isFlipping = false
    @State private var coinResult: Player?

    var body: some View {
        VStack(spacing: 24) {
            Text("Who serves first?")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                Button(player1.name) {
                    onPlayerSelected(player1)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button(player2.name) {
                    onPlayerSelected(player2)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button(action: tossCoin) {
                    HStack {
                        CoinView(
                            player1: player1,
                            player2: player2,
                            isFlipping: isFlipping,
                            result: coinResult
                        )
                        Text("Toss for it")
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(isFlipping)
            }

            if let result = coinResult, !isFlipping {
                Text("🎾 \(result.name) serves first! 🎾")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                    .scaleEffect(1.1)
                    .animation(.easeOut(duration: 0.3), value: coinResult)
                    .onAppear {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        // Auto-select after longer delay for dramatic effect
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            onPlayerSelected(result)
                        }
                    }
            }
        }
        .padding()
    }

    private func tossCoin() {
        isFlipping = true
        coinResult = nil

        // Add initial haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Longer, more dramatic flip duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            coinResult = Bool.random() ? player1 : player2
            isFlipping = false
        }
    }
}

struct CoinView: View {
    let player1: Player
    let player2: Player
    let isFlipping: Bool
    let result: Player?

    var body: some View {
        ZStack {
            // Coin background
            Circle()
                .fill(.yellow.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(.orange, lineWidth: 2)
                )

            // Player names on coin faces
            if isFlipping {
                // Show spinning coin during flip
                Text("🪙")
                    .font(.title2)
                    .rotationEffect(.degrees(isFlipping ? 1440 : 0)) // 4 full rotations
                    .animation(.easeOut(duration: 2.0), value: isFlipping)
            } else if let winner = result {
                // Show winner's initial after flip
                Text(String(winner.name.prefix(1)))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .scaleEffect(result != nil ? 1.2 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: result)
            } else {
                // Show coin emoji when idle
                Text("🪙")
                    .font(.title2)
            }
        }
        .scaleEffect(isFlipping ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isFlipping)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Player.self, Match.self, Point.self], inMemory: true)
}