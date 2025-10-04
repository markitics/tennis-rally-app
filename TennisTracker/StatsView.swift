//
//  StatsView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData
import Charts
import MapKit

struct StatsView: View {
    let matches: [Match]
    @Binding var selectedMatch: Match?

    @Environment(\.modelContext) private var modelContext
    @State private var filterMode: FilterMode = .allSets
    @State private var showingDeleteAlert = false
    @State private var showingNoteEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            if matches.isEmpty {
                EmptyStatsView()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Match selector
                    MatchSelectorView(
                        matches: matches,
                        selectedMatch: $selectedMatch
                    )

                    if let match = selectedMatch {
                        Divider()

                        // Match title (editable)
                        MatchTitleView(match: match)

                        Divider()

                        // Set selector
                        SetSelectorView(
                            match: match,
                            filterMode: $filterMode
                        )

                        // Match result (shown for all filter modes)
                        MatchResultView(match: match, filterMode: filterMode)

                        switch filterMode {
                        case .byGamePointsWon:
                            // By-game: Points Won
                            ByGamePointsWonView(match: match)

                        case .byGamePointsEnded:
                            // By-game: Points Ended
                            ByGamePointsEndedView(match: match)

                        default:
                            StatsContentView(
                                match: match,
                                filterMode: filterMode
                            )
                        }

                        // Action buttons (shown for all filter modes)
                        MatchActionButtonsView(
                            match: match,
                            onEndMatch: { endMatch(match) },
                            onDeleteMatch: { showingDeleteAlert = true },
                            onAddNote: { showingNoteEditor = true }
                        )
                    }
                }
            }

            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 100)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            if selectedMatch == nil && !matches.isEmpty {
                selectedMatch = matches.first
            }
        }
        .alert("Delete Match", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let match = selectedMatch {
                    deleteMatch(match)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this match? This action cannot be undone.")
        }
        .sheet(isPresented: $showingNoteEditor) {
            if let match = selectedMatch {
                NoteEditorView(match: match)
            }
        }
    }

    private func endMatch(_ match: Match) {
        match.isCompleted = true
    }

    private func deleteMatch(_ match: Match) {
        modelContext.delete(match)
        if selectedMatch?.id == match.id {
            selectedMatch = matches.first { $0.id != match.id }
        }
    }
}

struct EmptyStatsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("No matches yet")
                .font(.headline)
            Text("Start playing in the Play tab to see statistics here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MatchSelectorView: View {
    let matches: [Match]
    @Binding var selectedMatch: Match?

    private var sortedMatches: [Match] {
        matches.sorted { $0.matchDate > $1.matchDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match")
                .font(.headline)

            Picker("Select Match", selection: $selectedMatch) {
                ForEach(sortedMatches) { match in
                    Text(formatMatchLabel(match))
                        .padding(.vertical, 2)
                        .tag(Optional(match))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func formatMatchLabel(_ match: Match) -> String {
        if let title = match.title, !title.isEmpty {
            return title
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E d MMM yyyy 'at' HH:mm"
        return dateFormatter.string(from: match.matchDate)
    }
}

struct MatchTitleView: View {
    let match: Match
    @State private var editedTitle: String = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side: Title and date
            VStack(alignment: .leading, spacing: 8) {
                // Editable title
                TextField(formatDatePlaceholder(match.matchDate), text: $editedTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .lineLimit(1)
                    .onChange(of: editedTitle) { oldValue, newValue in
                        // Limit to 80 characters
                        if newValue.count > 80 {
                            editedTitle = String(newValue.prefix(80))
                        }
                        // Auto-save
                        match.title = newValue.isEmpty ? nil : newValue
                    }
                    .onChange(of: match.id) { oldValue, newValue in
                        // Update editedTitle when match changes
                        editedTitle = match.title ?? ""
                    }
                    .onAppear {
                        editedTitle = match.title ?? ""
                    }

                // Date subtitle (always visible)
                Text(formatDateSubtitle(match.matchDate))
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Weather info (if available)
                if let temp = match.temperature,
                   let condition = match.weatherCondition,
                   let symbol = match.weatherSymbol {
                    let fahrenheit = (temp * 9/5) + 32
                    HStack(spacing: 4) {
                        Image(systemName: symbol)
                        Text("\(Int(temp))°C / \(Int(fahrenheit))°F")
                        Text("·")
                        Text(condition)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    // Debug: show if we have location but no weather
                    if match.latitude != nil && match.longitude != nil {
                        Text("🌤️ Fetching weather...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Right side: Small map if location available
            if let latitude = match.latitude, let longitude = match.longitude {
                MapSnapshotView(latitude: latitude, longitude: longitude)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDatePlaceholder(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E d MMM yyyy 'at' HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateSubtitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy 'at' HH:mm"
        return "📅 " + formatter.string(from: date)
    }
}

struct MapSnapshotView: View {
    let latitude: Double
    let longitude: Double

    @State private var region: MKCoordinateRegion
    @State private var showingFullMap = false

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        Map(position: .constant(.region(region))) {
            Marker("Match Location", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        .frame(width: 80, height: 80)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            showingFullMap = true
        }
        .sheet(isPresented: $showingFullMap) {
            FullMapView(latitude: latitude, longitude: longitude)
        }
    }
}

struct FullMapView: View {
    let latitude: Double
    let longitude: Double
    @Environment(\.dismiss) private var dismiss

    @State private var region: MKCoordinateRegion

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    var body: some View {
        NavigationStack {
            Map(position: .constant(.region(region))) {
                Marker("Match Location", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }
            .navigationTitle("Match Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MatchResultView: View {
    let match: Match
    let filterMode: FilterMode

    private var scoreInfo: (winner: String?, score: String) {
        if case .bySet(let setNumber) = filterMode {
            // Show individual set score
            let setPoints = match.sortedPoints.filter { $0.setNumber == setNumber }
            let derivedState = ScoreEngine.compute(
                visiblePoints: setPoints,
                fullPoints: setPoints,
                p1: match.playerOne.id,
                p2: match.playerTwo.id,
                firstServerID: match.firstServerID
            )

            if let setScore = derivedState.setScores.first {
                if setScore.p1Games > setScore.p2Games {
                    return (match.playerOne.name, "Set \(setNumber): \(setScore.p1Games)-\(setScore.p2Games)")
                } else if setScore.p2Games > setScore.p1Games {
                    return (match.playerTwo.name, "Set \(setNumber): \(setScore.p1Games)-\(setScore.p2Games)")
                } else {
                    return (nil, "Set \(setNumber): \(setScore.p1Games)-\(setScore.p2Games)")
                }
            }
            return (nil, "Set \(setNumber)")
        } else {
            // Show full match score
            let derivedState = ScoreEngine.compute(
                visiblePoints: match.sortedPoints,
                fullPoints: match.sortedPoints,
                p1: match.playerOne.id,
                p2: match.playerTwo.id,
                firstServerID: match.firstServerID
            )

            let p1Sets = derivedState.setScores.filter { $0.p1Games > $0.p2Games }.count
            let p2Sets = derivedState.setScores.filter { $0.p2Games > $0.p1Games }.count

            let setScoresStr = derivedState.setScores.map { "\($0.p1Games)-\($0.p2Games)" }.joined(separator: ", ")

            if p1Sets > p2Sets {
                return (match.playerOne.name, setScoresStr)
            } else if p2Sets > p1Sets {
                return (match.playerTwo.name, setScoresStr)
            } else {
                return (nil, setScoresStr.isEmpty ? "No sets completed" : setScoresStr)
            }
        }
    }

    var body: some View {
        if let winner = scoreInfo.winner {
            Text("\(winner) wins: \(scoreInfo.score)")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
        } else {
            Text(scoreInfo.score)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
        }
    }
}

enum FilterMode: Hashable {
    case allSets
    case bySet(Int)
    case byGamePointsWon
    case byGamePointsEnded
}

enum ByGameMode: String, CaseIterable {
    case pointsWon = "Points won"
    case pointsEnded = "Points ended"
}

struct StatsContentView: View {
    let match: Match
    let filterMode: FilterMode

    private var filteredPoints: [Point] {
        switch filterMode {
        case .allSets:
            return match.sortedPoints
        case .bySet(let setNumber):
            return match.sortedPoints.filter { $0.setNumber == setNumber }
        case .byGamePointsWon, .byGamePointsEnded:
            return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Points Won chart
            PointsChartView(
                match: match,
                filteredPoints: filteredPoints
            )

            // Points Played chart
            PointsPlayedChartView(
                match: match,
                filteredPoints: filteredPoints
            )

            // Stats table
            StatsTableView(
                match: match,
                filterMode: filterMode
            )
        }
    }
}

struct SetSelectorView: View {
    let match: Match
    @Binding var filterMode: FilterMode

    @State private var selectedBySetOption: Int = 1
    @State private var selectedByGameOption: ByGameMode = .pointsEnded

    private var setsWithPoints: [Int] {
        let uniqueSets = Set(match.sortedPoints.map { $0.setNumber })
        return uniqueSets.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("View")
                .font(.headline)

            HStack(spacing: 12) {
                // All Sets button
                Button(action: {
                    filterMode = .allSets
                }) {
                    Text("All sets")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(filterMode == .allSets ? Color.accentColor : Color.clear)
                        .foregroundColor(filterMode == .allSets ? .white : .primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // By Set dropdown
                Menu {
                    ForEach(setsWithPoints, id: \.self) { setNumber in
                        Button("Set \(setNumber)") {
                            selectedBySetOption = setNumber
                            filterMode = .bySet(setNumber)
                        }
                    }
                } label: {
                    let isSelected: Bool = {
                        if case .bySet = filterMode { return true }
                        return false
                    }()

                    HStack {
                        Text("By set")
                        if case .bySet(let setNumber) = filterMode {
                            Text("(\(setNumber))")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.accentColor : Color.clear)
                    .foregroundColor(isSelected ? .white : .primary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                }

                // By Game dropdown
                Menu {
                    ForEach(ByGameMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) {
                            selectedByGameOption = mode
                            switch mode {
                            case .pointsWon:
                                filterMode = .byGamePointsWon
                            case .pointsEnded:
                                filterMode = .byGamePointsEnded
                            }
                        }
                    }
                } label: {
                    let isSelected: Bool = {
                        if case .byGamePointsWon = filterMode { return true }
                        if case .byGamePointsEnded = filterMode { return true }
                        return false
                    }()

                    HStack {
                        Text("By game")
                        if case .byGamePointsWon = filterMode {
                            Text("(Won)")
                                .foregroundColor(.secondary)
                        } else if case .byGamePointsEnded = filterMode {
                            Text("(Ended)")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.accentColor : Color.clear)
                    .foregroundColor(isSelected ? .white : .primary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                }
            }
        }
    }
}

struct StatsTableView: View {
    let match: Match
    let filterMode: FilterMode

    private var filteredPoints: [Point] {
        switch filterMode {
        case .allSets:
            return match.sortedPoints
        case .bySet(let setNumber):
            return match.sortedPoints.filter { $0.setNumber == setNumber }
        case .byGamePointsWon, .byGamePointsEnded:
            return []
        }
    }

    private var finalScoreWithWinner: (winner: String?, score: String) {
        if case .bySet(let setNumber) = filterMode {
            // Show individual set score with winner first
            let setPoints = match.sortedPoints.filter { $0.setNumber == setNumber }
            let derivedState = ScoreEngine.compute(
                visiblePoints: setPoints,
                fullPoints: setPoints,
                p1: match.playerOne.id,
                p2: match.playerTwo.id,
                firstServerID: match.firstServerID
            )

            // For individual sets, check if it's completed or in progress
            if let completedSet = derivedState.setScores.first {
                // Set is completed - show winner and final score
                let p1Games = completedSet.p1Games
                let p2Games = completedSet.p2Games

                if p1Games > p2Games {
                    return (winner: match.playerOne.name, score: "\(p1Games)-\(p2Games)")
                } else if p2Games > p1Games {
                    return (winner: match.playerTwo.name, score: "\(p2Games)-\(p1Games)")
                }
            } else {
                // Set is incomplete - show who's leading with current score
                let currentScore = derivedState.currentScoreString

                // Determine who's leading in the current incomplete set
                if let leaderID = derivedState.leaderID {
                    let leaderName = leaderID == match.playerOne.id ? match.playerOne.name : match.playerTwo.name
                    return (winner: nil, score: "\(leaderName) leads \(currentScore) (incomplete set)")
                } else {
                    // Tied or no clear leader
                    return (winner: nil, score: "Tied \(currentScore) (incomplete set)")
                }
            }

            return (winner: nil, score: "0-0 (incomplete set)")
        } else {
            // Show overall match score
            let derivedState = ScoreEngine.compute(
                visiblePoints: match.sortedPoints,
                fullPoints: match.sortedPoints,
                p1: match.playerOne.id,
                p2: match.playerTwo.id,
                firstServerID: match.firstServerID
            )

            let score = derivedState.endScoreString

            // Determine overall winner based on completed sets
            if let leaderID = derivedState.leaderID {
                let winnerName = leaderID == match.playerOne.id ? match.playerOne.name : match.playerTwo.name
                return (winner: winnerName, score: score)
            }

            return (winner: nil, score: score)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
//            // Stats for each player -- commented out because we have the charts above
//            VStack(spacing: 12) {
//                PlayerStatsView(
//                    player: match.playerOne,
//                    points: filteredPoints
//                )
//
//                Divider()
//
//                PlayerStatsView(
//                    player: match.playerTwo,
//                    points: filteredPoints
//                )
//            }
        }
    }
}

struct PlayerStatsView: View {
    let player: Player
    let points: [Point]

    private var playerPoints: [Point] {
        points.filter { $0.winner.id == player.id }
    }

    private var totalWinners: Int {
        playerPoints.filter { $0.type == .winner }.count
    }

    private var aces: Int {
        playerPoints.filter { $0.type == .ace }.count
    }

    private var totalUnforcedErrors: Int {
        playerPoints.filter { $0.type == .unforcedError || $0.type == .doubleFault }.count
    }

    private var doubleFaults: Int {
        playerPoints.filter { $0.type == .doubleFault }.count
    }

    // Removed unknown points - now tracking everything explicitly

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(player.name)
                .font(.headline)

            Group {
                Text("Total Winners: \(totalWinners) (Aces: \(aces))")
                Text("Total Unforced Errors: \(totalUnforcedErrors) (Double faults: \(doubleFaults))")
                Text("Total Points Won: \(playerPoints.count)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

struct MatchActionButtonsView: View {
    let match: Match
    let onEndMatch: () -> Void
    let onDeleteMatch: () -> Void
    let onAddNote: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Display note if it exists (tappable to edit) - shown during AND after match
            if let notes = match.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Match Notes")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Button(action: onAddNote) {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }

            // Action buttons
            HStack(spacing: 16) {
                // Add Note button (only if no note exists)
                if match.notes?.isEmpty != false {
                    Button("Add Note") {
                        onAddNote()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }

                // The only conditional: End Match vs Delete Match
                if !match.isCompleted {
                    Button("End Match") {
                        onEndMatch()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Delete Match") {
                        onDeleteMatch()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top)
        .padding(.bottom, 24) // Extra whitespace above tab bar
    }
}

struct NoteEditorView: View {
    let match: Match
    @State private var noteText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $noteText)
                    .navigationTitle("Add Note")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                match.notes = noteText.isEmpty ? nil : noteText
                                dismiss()
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
            .padding()
        }
        .onAppear {
            noteText = match.notes ?? ""
        }
    }
}

struct PointsChartView: View {
    let match: Match
    let filteredPoints: [Point]

    private func getPointCounts(for player: Player) -> (aces: Int, winners: Int, doubleFaults: Int, unforcedErrors: Int) {
        let wonPoints = filteredPoints.filter { $0.winner.id == player.id }

        let aces = wonPoints.filter { $0.type == .ace }.count
        let winners = wonPoints.filter { $0.type == .winner }.count
        let doubleFaults = wonPoints.filter { $0.type == .doubleFault }.count
        let unforcedErrors = wonPoints.filter { $0.type == .unforcedError }.count

        return (aces, winners, doubleFaults, unforcedErrors)
    }

    private var maxPoints: Int {
        let player1Total = filteredPoints.filter { $0.winner.id == match.playerOne.id }.count
        let player2Total = filteredPoints.filter { $0.winner.id == match.playerTwo.id }.count
        return max(player1Total, player2Total, 1) // At least 1 to avoid division by zero
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Points won by this player")
                .font(.headline)

            VStack(spacing: 16) {
                // Player 1 bar with individual legend
                VStack(alignment: .leading, spacing: 4) {
                    HorizontalPlayerBarView(
                        player: match.playerOne,
                        points: getPointCounts(for: match.playerOne),
                        total: filteredPoints.filter { $0.winner.id == match.playerOne.id }.count,
                        maxPoints: maxPoints
                    )

                    // Individual legend for player 1
                    let p1Points = getPointCounts(for: match.playerOne)
                    HStack(spacing: 12) {
                        PlayerLegendItem(color: .yellow, count: p1Points.aces, text: "Aces")
                        PlayerLegendItem(color: .teal, count: p1Points.winners, text: "Winners")
                        PlayerLegendItem(color: .red, count: p1Points.doubleFaults, text: "Double Faults")
                        PlayerLegendItem(color: .pink, count: p1Points.unforcedErrors, text: "Unforced Errors")
                        Spacer()
                    }
                    .font(.caption2)
                }

                // Player 2 bar with individual legend
                VStack(alignment: .leading, spacing: 4) {
                    HorizontalPlayerBarView(
                        player: match.playerTwo,
                        points: getPointCounts(for: match.playerTwo),
                        total: filteredPoints.filter { $0.winner.id == match.playerTwo.id }.count,
                        maxPoints: maxPoints
                    )

                    // Individual legend for player 2
                    let p2Points = getPointCounts(for: match.playerTwo)
                    HStack(spacing: 12) {
                        PlayerLegendItem(color: .yellow, count: p2Points.aces, text: "Aces")
                        PlayerLegendItem(color: .teal, count: p2Points.winners, text: "Winners")
                        PlayerLegendItem(color: .red, count: p2Points.doubleFaults, text: "Double Faults")
                        PlayerLegendItem(color: .pink, count: p2Points.unforcedErrors, text: "Unforced Errors")
                        Spacer()
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(.vertical)
    }
}

struct HorizontalPlayerBarView: View {
    let player: Player
    let points: (aces: Int, winners: Int, doubleFaults: Int, unforcedErrors: Int)
    let total: Int
    let maxPoints: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Player name and total
            HStack {
                Text(player.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(total) points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Horizontal bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if total > 0 {
                        let totalWidth = geometry.size.width * (CGFloat(total) / CGFloat(maxPoints))

                        // Aces (gold)
                        if points.aces > 0 {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: totalWidth * CGFloat(points.aces) / CGFloat(total))
                        }

                        // Winners (teal)
                        if points.winners > 0 {
                            Rectangle()
                                .fill(Color.teal)
                                .frame(width: totalWidth * CGFloat(points.winners) / CGFloat(total))
                        }

                        // Double faults (red)
                        if points.doubleFaults > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: totalWidth * CGFloat(points.doubleFaults) / CGFloat(total))
                        }

                        // Unforced errors (pink)
                        if points.unforcedErrors > 0 {
                            Rectangle()
                                .fill(Color.pink)
                                .frame(width: totalWidth * CGFloat(points.unforcedErrors) / CGFloat(total))
                        }

                        Spacer()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 20)
                        Spacer()
                    }
                }
            }
            .frame(height: 24)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct PlayerLegendItem: View {
    let color: Color
    let count: Int
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 10)
                .cornerRadius(2)

            Text("\(count) \(text)")
        }
    }
}

struct PointsPlayedChartView: View {
    let match: Match
    let filteredPoints: [Point]

    private func getPointsPlayed(for player: Player) -> (aces: Int, winners: Int, doubleFaults: Int, unforcedErrors: Int) {
        // Get points where this player ended the point (either won or lost due to their action)
        let playerActionPoints = filteredPoints.filter { point in
            // Player won the point with their action
            if point.winner.id == player.id {
                return true
            }
            // Player lost the point due to their error
            if point.loser.id == player.id && (point.type == .doubleFault || point.type == .unforcedError) {
                return true
            }
            return false
        }

        let aces = playerActionPoints.filter { $0.type == .ace && $0.winner.id == player.id }.count
        let winners = playerActionPoints.filter { $0.type == .winner && $0.winner.id == player.id }.count
        let doubleFaults = playerActionPoints.filter { $0.type == .doubleFault && $0.loser.id == player.id }.count
        let unforcedErrors = playerActionPoints.filter { $0.type == .unforcedError && $0.loser.id == player.id }.count

        return (aces, winners, doubleFaults, unforcedErrors)
    }

    private var maxPointsPlayed: Int {
        let player1Played = getPointsPlayed(for: match.playerOne)
        let player1Total = player1Played.aces + player1Played.winners + player1Played.doubleFaults + player1Played.unforcedErrors

        let player2Played = getPointsPlayed(for: match.playerTwo)
        let player2Total = player2Played.aces + player2Played.winners + player2Played.doubleFaults + player2Played.unforcedErrors

        return max(player1Total, player2Total, 1) // At least 1 to avoid division by zero
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Points ended by this player")
                .font(.headline)

            VStack(spacing: 16) {
                // Player 1 bar with individual legend
                VStack(alignment: .leading, spacing: 4) {
                    HorizontalPlayerPlayedBarView(
                        player: match.playerOne,
                        points: getPointsPlayed(for: match.playerOne),
                        maxPoints: maxPointsPlayed
                    )

                    // Individual legend for player 1
                    let p1Played = getPointsPlayed(for: match.playerOne)
                    HStack(spacing: 12) {
                        PlayerLegendItem(color: .yellow, count: p1Played.aces, text: "Aces")
                        PlayerLegendItem(color: .teal, count: p1Played.winners, text: "Winners")
                        PlayerLegendItem(color: .red, count: p1Played.doubleFaults, text: "Double Faults")
                        PlayerLegendItem(color: .pink, count: p1Played.unforcedErrors, text: "Unforced Errors")
                        Spacer()
                    }
                    .font(.caption2)
                }

                // Player 2 bar with individual legend
                VStack(alignment: .leading, spacing: 4) {
                    HorizontalPlayerPlayedBarView(
                        player: match.playerTwo,
                        points: getPointsPlayed(for: match.playerTwo),
                        maxPoints: maxPointsPlayed
                    )

                    // Individual legend for player 2
                    let p2Played = getPointsPlayed(for: match.playerTwo)
                    HStack(spacing: 12) {
                        PlayerLegendItem(color: .yellow, count: p2Played.aces, text: "Aces")
                        PlayerLegendItem(color: .teal, count: p2Played.winners, text: "Winners")
                        PlayerLegendItem(color: .red, count: p2Played.doubleFaults, text: "Double Faults")
                        PlayerLegendItem(color: .pink, count: p2Played.unforcedErrors, text: "Unforced Errors")
                        Spacer()
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(.vertical)
    }
}

struct HorizontalPlayerPlayedBarView: View {
    let player: Player
    let points: (aces: Int, winners: Int, doubleFaults: Int, unforcedErrors: Int)
    let maxPoints: Int

    private var total: Int {
        points.aces + points.winners + points.doubleFaults + points.unforcedErrors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Player name and total
            HStack {
                Text(player.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(total) shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Horizontal bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if total > 0 {
                        let totalWidth = geometry.size.width * (CGFloat(total) / CGFloat(maxPoints))

                        // Aces (gold)
                        if points.aces > 0 {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: totalWidth * CGFloat(points.aces) / CGFloat(total))
                        }

                        // Winners (teal)
                        if points.winners > 0 {
                            Rectangle()
                                .fill(Color.teal)
                                .frame(width: totalWidth * CGFloat(points.winners) / CGFloat(total))
                        }

                        // Double faults (red)
                        if points.doubleFaults > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: totalWidth * CGFloat(points.doubleFaults) / CGFloat(total))
                        }

                        // Unforced errors (pink)
                        if points.unforcedErrors > 0 {
                            Rectangle()
                                .fill(Color.pink)
                                .frame(width: totalWidth * CGFloat(points.unforcedErrors) / CGFloat(total))
                        }

                        Spacer()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 20)
                        Spacer()
                    }
                }
            }
            .frame(height: 24)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - By Game: Points Won (pyramid chart)
struct ByGamePointsWonView: View {
    let match: Match

    struct GameData: Identifiable {
        let id: String
        let setNumber: Int
        let gameNumber: Int
        let p1Aces: Int
        let p1Winners: Int
        let p1OpponentErrors: Int  // Points won from opponent's errors
        let p2Aces: Int
        let p2Winners: Int
        let p2OpponentErrors: Int

        var label: String {
            "S\(setNumber)G\(gameNumber)"
        }
    }

    private var gameDataList: [GameData] {
        let groupedPoints = Dictionary(grouping: match.sortedPoints) { point in
            "\(point.setNumber)-\(point.gameNumber)"
        }

        var games: [GameData] = []
        for (key, points) in groupedPoints.sorted(by: { $0.key < $1.key }) {
            guard let firstPoint = points.first else { continue }

            let p1WonPoints = points.filter { $0.winner.id == match.playerOne.id }
            let p2WonPoints = points.filter { $0.winner.id == match.playerTwo.id }

            games.append(GameData(
                id: key,
                setNumber: firstPoint.setNumber,
                gameNumber: firstPoint.gameNumber,
                p1Aces: p1WonPoints.filter { $0.type == .ace }.count,
                p1Winners: p1WonPoints.filter { $0.type == .winner }.count,
                p1OpponentErrors: p1WonPoints.filter { $0.type == .doubleFault || $0.type == .unforcedError }.count,
                p2Aces: p2WonPoints.filter { $0.type == .ace }.count,
                p2Winners: p2WonPoints.filter { $0.type == .winner }.count,
                p2OpponentErrors: p2WonPoints.filter { $0.type == .doubleFault || $0.type == .unforcedError }.count
            ))
        }

        return games.sorted { game1, game2 in
            if game1.setNumber != game2.setNumber {
                return game1.setNumber < game2.setNumber
            }
            return game1.gameNumber < game2.gameNumber
        }
    }

    struct ChartPoint: Identifiable {
        let id = UUID()
        let game: String
        let type: String
        let value: Int
        let color: Color
    }

    private var chartPoints: [ChartPoint] {
        var points: [ChartPoint] = []

        for game in gameDataList {
            // Player 1 (Mark) on the left (negative values)
            points.append(ChartPoint(game: game.label, type: "P1OppErr", value: -game.p1OpponentErrors, color: .pink))
            points.append(ChartPoint(game: game.label, type: "P1W", value: -game.p1Winners, color: .green))
            points.append(ChartPoint(game: game.label, type: "P1A", value: -game.p1Aces, color: .yellow))

            // Player 2 (Jeff) on the right (positive values)
            points.append(ChartPoint(game: game.label, type: "P2OppErr", value: game.p2OpponentErrors, color: .pink))
            points.append(ChartPoint(game: game.label, type: "P2W", value: game.p2Winners, color: .green))
            points.append(ChartPoint(game: game.label, type: "P2A", value: game.p2Aces, color: .yellow))
        }

        return points
    }

    private var maxValue: Int {
        let allAbsoluteValues = chartPoints.map { abs($0.value) }
        return allAbsoluteValues.max() ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Points won per game")
                    .font(.headline)
                    .padding(.horizontal)

                // Legend
                HStack(spacing: 12) {
                    Text(match.playerOne.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("←")
                    Spacer()
                    Text("→")
                    Text(match.playerTwo.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    LegendItem(color: .yellow, text: "Aces")
                    LegendItem(color: .green, text: "Winners")
                    LegendItem(color: .pink, text: "Opp. Errors")
                }
                .padding(.horizontal)
                .font(.caption)

                // Population pyramid chart
                Chart {
                    ForEach(chartPoints) { point in
                        BarMark(
                            x: .value("Count", point.value),
                            y: .value("Game", point.game)
                        )
                        .foregroundStyle(point.color)
                    }
                }
                .chartXScale(domain: -maxValue...maxValue)
                .chartXAxis {
                    AxisMarks(position: .bottom, values: [0]) { value in
                        AxisValueLabel {
                            Text("")
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: max(CGFloat(gameDataList.count) * 30, 200))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - By Game: Points Ended (pyramid chart - same as pyramid view)
struct ByGamePointsEndedView: View {
    let match: Match

    struct GameData: Identifiable {
        let id: String
        let setNumber: Int
        let gameNumber: Int
        let p1Aces: Int
        let p1Winners: Int
        let p1DoubleFaults: Int
        let p1UnforcedErrors: Int
        let p2Aces: Int
        let p2Winners: Int
        let p2DoubleFaults: Int
        let p2UnforcedErrors: Int

        var label: String {
            "S\(setNumber)G\(gameNumber)"
        }
    }

    private var gameDataList: [GameData] {
        let groupedPoints = Dictionary(grouping: match.sortedPoints) { point in
            "\(point.setNumber)-\(point.gameNumber)"
        }

        var games: [GameData] = []
        for (key, points) in groupedPoints.sorted(by: { $0.key < $1.key }) {
            guard let firstPoint = points.first else { continue }

            let p1EndedPoints = points.filter { point in
                if point.winner.id == match.playerOne.id { return true }
                if point.loser.id == match.playerOne.id && (point.type == .doubleFault || point.type == .unforcedError) { return true }
                return false
            }

            let p2EndedPoints = points.filter { point in
                if point.winner.id == match.playerTwo.id { return true }
                if point.loser.id == match.playerTwo.id && (point.type == .doubleFault || point.type == .unforcedError) { return true }
                return false
            }

            games.append(GameData(
                id: key,
                setNumber: firstPoint.setNumber,
                gameNumber: firstPoint.gameNumber,
                p1Aces: p1EndedPoints.filter { $0.type == .ace && $0.winner.id == match.playerOne.id }.count,
                p1Winners: p1EndedPoints.filter { $0.type == .winner && $0.winner.id == match.playerOne.id }.count,
                p1DoubleFaults: p1EndedPoints.filter { $0.type == .doubleFault && $0.loser.id == match.playerOne.id }.count,
                p1UnforcedErrors: p1EndedPoints.filter { $0.type == .unforcedError && $0.loser.id == match.playerOne.id }.count,
                p2Aces: p2EndedPoints.filter { $0.type == .ace && $0.winner.id == match.playerTwo.id }.count,
                p2Winners: p2EndedPoints.filter { $0.type == .winner && $0.winner.id == match.playerTwo.id }.count,
                p2DoubleFaults: p2EndedPoints.filter { $0.type == .doubleFault && $0.loser.id == match.playerTwo.id }.count,
                p2UnforcedErrors: p2EndedPoints.filter { $0.type == .unforcedError && $0.loser.id == match.playerTwo.id }.count
            ))
        }

        return games.sorted { game1, game2 in
            if game1.setNumber != game2.setNumber {
                return game1.setNumber < game2.setNumber
            }
            return game1.gameNumber < game2.gameNumber
        }
    }

    struct ChartPoint: Identifiable {
        let id = UUID()
        let game: String
        let type: String
        let value: Int
        let color: Color
    }

    private var chartPoints: [ChartPoint] {
        var points: [ChartPoint] = []

        for game in gameDataList {
            // Player 1 (Mark) on the left (negative values)
            points.append(ChartPoint(game: game.label, type: "P1UE", value: -game.p1UnforcedErrors, color: .pink))
            points.append(ChartPoint(game: game.label, type: "P1DF", value: -game.p1DoubleFaults, color: .red))
            points.append(ChartPoint(game: game.label, type: "P1W", value: -game.p1Winners, color: .green))
            points.append(ChartPoint(game: game.label, type: "P1A", value: -game.p1Aces, color: .yellow))

            // Player 2 (Jeff) on the right (positive values)
            points.append(ChartPoint(game: game.label, type: "P2UE", value: game.p2UnforcedErrors, color: .pink))
            points.append(ChartPoint(game: game.label, type: "P2DF", value: game.p2DoubleFaults, color: .red))
            points.append(ChartPoint(game: game.label, type: "P2W", value: game.p2Winners, color: .green))
            points.append(ChartPoint(game: game.label, type: "P2A", value: game.p2Aces, color: .yellow))
        }

        return points
    }

    private var maxValue: Int {
        let allAbsoluteValues = chartPoints.map { abs($0.value) }
        return allAbsoluteValues.max() ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Points ended per game")
                    .font(.headline)
                    .padding(.horizontal)

                // Legend
                HStack(spacing: 12) {
                    Text(match.playerOne.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("←")
                    Spacer()
                    Text("→")
                    Text(match.playerTwo.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    LegendItem(color: .yellow, text: "Aces")
                    LegendItem(color: .green, text: "Winners")
                    LegendItem(color: .red, text: "DF")
                    LegendItem(color: .pink, text: "UE")
                }
                .padding(.horizontal)
                .font(.caption)

                // Population pyramid chart
                Chart {
                    ForEach(chartPoints) { point in
                        BarMark(
                            x: .value("Count", point.value),
                            y: .value("Game", point.game)
                        )
                        .foregroundStyle(point.color)
                    }
                }
                .chartXScale(domain: -maxValue...maxValue)
                .chartXAxis {
                    AxisMarks(position: .bottom, values: [0]) { value in
                        AxisValueLabel {
                            Text("")
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: max(CGFloat(gameDataList.count) * 30, 200))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct LegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 10)
                .cornerRadius(2)
            Text(text)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, Match.self, Point.self, configurations: config)

    let player1 = Player(name: "You")
    let player2 = Player(name: "Opponent")
    let match = Match(playerOne: player1, playerTwo: player2, firstServerID: player1.id)

    return StatsView(matches: [match], selectedMatch: .constant(match))
        .modelContainer(container)
}
