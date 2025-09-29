//
//  StatsView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    let matches: [Match]
    @Binding var selectedMatch: Match?

    @Environment(\.modelContext) private var modelContext
    @State private var selectedSet: Int? = nil
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
                        // Set selector
                        SetSelectorView(
                            match: match,
                            selectedSet: $selectedSet
                        )

                        // Points Won chart
                        PointsChartView(
                            match: match,
                            filteredPoints: selectedSet == nil ? match.sortedPoints : match.sortedPoints.filter { $0.setNumber == selectedSet }
                        )

                        // Points Played chart
                        PointsPlayedChartView(
                            match: match,
                            filteredPoints: selectedSet == nil ? match.sortedPoints : match.sortedPoints.filter { $0.setNumber == selectedSet }
                        )

                        // Stats table
                        StatsTableView(
                            match: match,
                            selectedSet: selectedSet
                        )

                        // Action buttons
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
        }
        .padding()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match")
                .font(.headline)

            Picker("Select Match", selection: $selectedMatch) {
                ForEach(matches) { match in
                    Text(formatMatchLabel(match))
                        .padding(.vertical, 2)
                        .tag(Optional(match))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func formatMatchLabel(_ match: Match) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: match.matchDate)
    }
}

struct SetSelectorView: View {
    let match: Match
    @Binding var selectedSet: Int?

    private var setCount: Int {
        ScoreEngine.currentSetNumber(
            from: match.sortedPoints,
            p1: match.playerOne.id,
            p2: match.playerTwo.id
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set Filter")
                .font(.headline)

            Picker("Set", selection: $selectedSet) {
                Text("All Sets").tag(nil as Int?)
                ForEach(1...setCount, id: \.self) { setNumber in
                    Text("Set \(setNumber)").tag(Optional(setNumber))
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct StatsTableView: View {
    let match: Match
    let selectedSet: Int?

    private var filteredPoints: [Point] {
        if let set = selectedSet {
            return match.sortedPoints.filter { $0.setNumber == set }
        }
        return match.sortedPoints
    }

    private var finalScoreWithWinner: (winner: String?, score: String) {
        if let setNumber = selectedSet {
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
            // Final score with winner
            let scoreInfo = finalScoreWithWinner
            if let winner = scoreInfo.winner {
                Text("\(winner) wins: \(scoreInfo.score)")
                    .font(.title3)
                    .fontWeight(.semibold)
            } else {
                Text(scoreInfo.score)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            // Stats for each player
            VStack(spacing: 12) {
                PlayerStatsView(
                    player: match.playerOne,
                    points: filteredPoints
                )

                Divider()

                PlayerStatsView(
                    player: match.playerTwo,
                    points: filteredPoints
                )
            }
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
            if !match.isCompleted {
                Button("End Match") {
                    onEndMatch()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 16) {
                    Button(match.notes?.isEmpty == false ? "Edit Note" : "Add Note") {
                        onAddNote()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, Match.self, Point.self, configurations: config)

    let player1 = Player(name: "You")
    let player2 = Player(name: "Opponent")
    let match = Match(playerOne: player1, playerTwo: player2, firstServerID: player1.id)

    return StatsView(matches: [match], selectedMatch: .constant(match))
        .modelContainer(container)
}
