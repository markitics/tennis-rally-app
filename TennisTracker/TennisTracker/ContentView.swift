//
//  ContentView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import CoreLocation
import WatchConnectivity

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
    @StateObject private var locationManager = LocationManager()

    // Debounce guards for Live Activity button presses
    @State private var lastPointTime: Date = .distantPast
    @State private var isProcessingPoint = false

    // Track processed action IDs to detect duplicates (thread-safe with actor)
    private static let actionIDStore = ActionIDStore()

    actor ActionIDStore {
        private var processedIDs: [String: Date] = [:]
        private let cleanupInterval: TimeInterval = 5.0

        func hasProcessed(actionID: String) -> Bool {
            // Clean up old IDs
            let cutoffTime = Date().addingTimeInterval(-cleanupInterval)
            processedIDs = processedIDs.filter { $0.value > cutoffTime }

            // Check if already processed
            return processedIDs[actionID] != nil
        }

        func markAsProcessed(actionID: String) {
            processedIDs[actionID] = Date()
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Play tab
            NavigationStack {
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
            }
            .tabItem {
                Label("Play", systemImage: "tennisball.fill")
            }
            .tag(Tab.play)

            // View tab
            NavigationStack {
                StatsView(matches: matches, selectedMatch: $selectedMatch)
            }
            .tabItem {
                Label("View", systemImage: "chart.bar.fill")
            }
            .tag(Tab.view)

            // Settings tab
            NavigationStack {
                SettingsView()
                    .environmentObject(liveActivityManager)
                    .environmentObject(matchViewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordPointFromWidget"))) { notification in
            handleWidgetPointAction(notification)
        }
        .onAppear {
            // Set up watch connectivity handler
            PhoneWatchConnectivity.shared.onWatchAction = { [self] action in
                guard let match = activeMatch else {
                    return nil
                }

                // Handle watch button press
                let player: Player
                let type = PointType.winner

                if action == "mark_winner" {
                    player = match.playerOne
                } else if action == "jeff_winner" {
                    player = match.playerTwo
                } else {
                    return nil
                }

                // Record the point (reuse existing logic!)
                recordPoint(match: match, player: player, type: type)

                // Return current score to watch
                let derivedState = matchViewModel.derivedState

                // Also send server name
                let serverID = ScoreEngine.currentServerID(
                    visiblePoints: Array(matchViewModel.cachedPoints.prefix(matchViewModel.cursor)),
                    p1: match.playerOne.id,
                    p2: match.playerTwo.id,
                    firstServerID: match.firstServerID,
                    tiebreakFirstServers: match.tiebreakFirstServers
                )
                let serverName = serverID == match.playerOne.id ? match.playerOne.name : match.playerTwo.name

                // Send server update via message (no reply needed)
                Task {
                    try? WCSession.default.updateApplicationContext(["server": serverName])
                }

                return derivedState.currentScoreString
            }
        }
    }

    // Handle point recording from Live Activity buttons - works from any tab
    private func handleWidgetPointAction(_ notification: Notification) {
        guard let match = activeMatch else {
            print("❌ No active match to record point")
            return
        }

        guard let userInfo = notification.userInfo,
              let pointTypeString = userInfo["pointType"] as? String,
              let playerName = userInfo["player"] as? String else {
            print("❌ Invalid widget action notification")
            return
        }

        // Extract action ID and timestamp for logging
        let actionID = userInfo["actionID"] as? String ?? "UNKNOWN"
        let intentTimestamp = userInfo["timestamp"] as? TimeInterval ?? 0
        let now = Date().timeIntervalSince1970
        let timeSinceIntent = now - intentTimestamp

        print("📥 WIDGET ACTION RECEIVED - ID: \(actionID)")
        print("📥   Point type: \(pointTypeString), Player: \(playerName)")
        print("📥   Time since intent: \(String(format: "%.3f", timeSinceIntent * 1000))ms")

        // Check for duplicate action ID using thread-safe actor
        Task {
            let alreadyProcessed = await ContentView.actionIDStore.hasProcessed(actionID: actionID)
            if alreadyProcessed {
                print("⚠️ DUPLICATE ACTION ID DETECTED!")
                print("⚠️   Action ID: \(actionID)")
                print("⚠️   REJECTING duplicate action")
                return
            }

            // Mark as processed
            await ContentView.actionIDStore.markAsProcessed(actionID: actionID)

            await processWidgetAction(pointTypeString: pointTypeString, playerName: playerName, actionID: actionID, match: match)
        }
    }

    @MainActor
    private func processWidgetAction(pointTypeString: String, playerName: String, actionID: String, match: Match) {
        print("📥   Processing action on main actor...")

        // Convert string to PointType
        let pointType: PointType
        switch pointTypeString {
        case "winner":
            pointType = .winner
        case "ace":
            pointType = .ace
        case "unforcedError":
            pointType = .unforcedError
        case "doubleFault":
            pointType = .doubleFault
        default:
            print("❌ Unknown point type: \(pointTypeString)")
            return
        }

        // Find the player - resolve "server" to actual current server
        let player: Player
        if playerName == "server" {
            let serverID = ScoreEngine.currentServerID(
                visiblePoints: Array(matchViewModel.cachedPoints.prefix(matchViewModel.cursor)),
                p1: match.playerOne.id,
                p2: match.playerTwo.id,
                firstServerID: match.firstServerID,
                tiebreakFirstServers: match.tiebreakFirstServers
            )
            player = (serverID == match.playerOne.id) ? match.playerOne : match.playerTwo
        } else if playerName == match.playerOne.name {
            player = match.playerOne
        } else if playerName == match.playerTwo.name {
            player = match.playerTwo
        } else {
            print("❌ Unknown player: '\(playerName)'")
            return
        }

        // Record the point directly
        recordPoint(match: match, player: player, type: pointType)
    }

    private func recordPoint(match: Match, player: Player, type: PointType) {
        let entryTime = Date()
        let timeSinceLastPoint = entryTime.timeIntervalSince(lastPointTime)

        print("🎯 RECORD POINT START")
        print("🎯   Type: \(type.rawValue), Player: \(player.name)")
        print("🎯   Time since last point: \(String(format: "%.3f", timeSinceLastPoint * 1000))ms")
        print("🎯   Current cursor: \(matchViewModel.cursor)")
        print("🎯   isProcessingPoint: \(isProcessingPoint)")

        // Debounce rapid button presses (50ms)
        guard timeSinceLastPoint > 0.05 else {
            print("⏭️ DEBOUNCE REJECTION - Too fast!")
            print("⏭️   Elapsed: \(String(format: "%.3f", timeSinceLastPoint * 1000))ms (need 50ms)")
            return
        }
        lastPointTime = entryTime

        // Prevent concurrent point processing
        guard !isProcessingPoint else {
            print("🔒 LOCK REJECTION - Already processing a point!")
            return
        }
        isProcessingPoint = true
        defer {
            isProcessingPoint = false
            print("🎯   isProcessingPoint released")
        }

        // Determine winner/loser based on point type
        let winner: Player
        let loser: Player
        switch type {
        case .doubleFault, .unforcedError:
            winner = (player.id == match.playerOne.id) ? match.playerTwo : match.playerOne
            loser = player
        case .ace, .winner:
            winner = player
            loser = (player.id == match.playerOne.id) ? match.playerTwo : match.playerOne
        }

        // Get current set and game numbers
        let setNumber = ScoreEngine.currentSetNumber(
            from: Array(matchViewModel.cachedPoints.prefix(matchViewModel.cursor)),
            p1: match.playerOne.id,
            p2: match.playerTwo.id
        )
        let gameNumber = ScoreEngine.currentGameNumber(
            from: Array(matchViewModel.cachedPoints.prefix(matchViewModel.cursor)),
            p1: match.playerOne.id,
            p2: match.playerTwo.id
        )

        // Create and insert point
        let newPoint = Point(
            match: match,
            winner: winner,
            loser: loser,
            type: type,
            setNumber: setNumber,
            gameNumber: gameNumber
        )

        // Add to cache FIRST (instant update!)
        matchViewModel.addPointToCache(newPoint)
        print("🎯   Point added to cache, cursor now: \(matchViewModel.cursor)")

        // Insert to SwiftData in background (we don't care about lag)
        modelContext.insert(newPoint)

        // Update Live Activity with fresh cached data
        if #available(iOS 16.1, *) {
            let derivedState = matchViewModel.derivedState  // Uses cachedPoints!

            let serverID = ScoreEngine.currentServerID(
                visiblePoints: Array(matchViewModel.cachedPoints.prefix(matchViewModel.cursor)),
                p1: match.playerOne.id,
                p2: match.playerTwo.id,
                firstServerID: match.firstServerID,
                tiebreakFirstServers: match.tiebreakFirstServers
            )
            let serverName = serverID == match.playerOne.id ? match.playerOne.name : match.playerTwo.name

            print("🎯     Computed score: \(derivedState.currentScoreString)")

            liveActivityManager.updateMatchActivity(
                derivedState: derivedState,
                serverName: serverName
            )
        }

        print("🎯 RECORD POINT COMPLETE - Success!")
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

        // Request fresh, accurate location for this match
        print("📍 Requesting fresh location for new match...")
        locationManager.requestLocation()

        // Create match with location (will be nil initially if location not ready)
        let newMatch = Match(
            playerOne: player1,
            playerTwo: player2,
            firstServerID: actualFirstServerID,
            latitude: nil,  // Will be updated when location arrives
            longitude: nil
        )

        modelContext.insert(newMatch)
        selectedMatch = newMatch  // Auto-select the new match in View tab
        showingFirstServerSelection = false

        // Wait for accurate location and update match + fetch weather
        Task {
            print("⏳ Waiting for accurate location (up to 12 seconds)...")
            var attempts = 0
            var bestLocation: CLLocation?

            // Wait up to 12 seconds for location (LocationManager waits up to 10s for accuracy)
            while attempts < 120 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                if let currentLoc = locationManager.currentLocation {
                    // Check if this is a new location (timestamp within last 15 seconds)
                    let age = abs(currentLoc.timestamp.timeIntervalSinceNow)
                    if age < 15.0 {
                        bestLocation = currentLoc
                        print("✅ Got fresh location: \(currentLoc.horizontalAccuracy)m accuracy, \(String(format: "%.1f", age))s old")
                        break
                    }
                }
                attempts += 1
            }

            // Update match with best available location
            if let location = bestLocation {
                newMatch.latitude = location.coordinate.latitude
                newMatch.longitude = location.coordinate.longitude
                print("📍 Match location saved: \(location.coordinate.latitude), \(location.coordinate.longitude) (±\(location.horizontalAccuracy)m)")

                // Fetch weather with the accurate location
                print("🌤️ Fetching weather for match location...")
                await WeatherService.shared.fetchWeather(
                    for: newMatch,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            } else {
                print("⚠️ No location available after \(attempts * 100)ms - match saved without location")
            }
        }

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
        VStack(spacing: 32) {
            Text("Who serves first?")
                .font(.title)
                .fontWeight(.semibold)

            // Large left-right buttons for players
            HStack(spacing: 16) {
                Button(action: {
                    onPlayerSelected(player1)
                }) {
                    Text(player1.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                }

                Button(action: {
                    onPlayerSelected(player2)
                }) {
                    Text(player2.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal)

            // Toss button or result
            if isFlipping {
                Text("Tossing coin...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let result = coinResult {
                VStack(spacing: 12) {
                    Text("\(result.name) won the toss")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(result.id == player1.id ? .blue : .orange)

                    Text("\(result.name) decides")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .onAppear {
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } else {
                Button(action: tossCoin) {
                    HStack {
                        CoinView(
                            player1: player1,
                            player2: player2,
                            isFlipping: false,
                            result: nil
                        )
                        Text("Toss for it")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    private func tossCoin() {
        isFlipping = true
        coinResult = nil

        // Add initial haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Coin flip duration
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