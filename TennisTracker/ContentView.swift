//
//  ContentView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData

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
                Group {
                    switch selectedTab {
                    case .play:
                        if let match = activeMatch {
                            PlayView(match: match, viewModel: matchViewModel)
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
                    }
                }
                .animation(.default, value: selectedTab)
            }
            .task {
                ensureMatchSelection()
            }
            .onChange(of: matches) { _ in
                ensureMatchSelection()
            }
            .onChange(of: activeMatch) { newMatch in
                if let match = newMatch {
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
        showingFirstServerSelection = false
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
                        if isFlipping {
                            Text("🪙")
                                .rotationEffect(.degrees(isFlipping ? 720 : 0))
                                .animation(.easeInOut(duration: 1.0), value: isFlipping)
                        } else {
                            Text("🪙")
                        }
                        Text("Toss for it")
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(isFlipping)
            }

            if let result = coinResult, !isFlipping {
                Text("\(result.name) serves first!")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            coinResult = Bool.random() ? player1 : player2
            isFlipping = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Player.self, Match.self, Point.self], inMemory: true)
}