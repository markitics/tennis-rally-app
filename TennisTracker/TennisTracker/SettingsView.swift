//
//  SettingsView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @EnvironmentObject var liveActivityManager: LiveActivityManager
    @EnvironmentObject var viewModel: MatchViewModel

    var body: some View {
        List {
            Section {
                Toggle(isOn: $soundEnabled) {
                    Label("Sound Effects", systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .tint(.blue)
            } header: {
                Text("Audio Feedback")
            } footer: {
                Text("Play sounds when recording points. Haptic feedback will continue to work regardless of this setting.")
            }

            if #available(iOS 16.1, *) {
                Section {
                    Button {
                        restartLiveActivity()
                    } label: {
                        Label("Restart Live Activity", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .disabled(viewModel.match == nil)
                } header: {
                    Text("Live Activity")
                } footer: {
                    Text("If you accidentally dismissed the Live Activity, tap here to bring it back.")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Created by")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Mark Moriarty")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    HStack {
                        Text("Last Updated")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Oct 5, 2025 7:24 PM PT")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    Text("Work in progress")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } header: {
                Text("About")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    RecentCommitRow(message: "Oct 5: Add Git Commit Workflow to CLAUDE.md, and store it in .claude/commands/commit.md, so the user can just type /commit and Claude will propose a draft commit message; if approved, Claude will commit and push to github, after hard-code updating the 'About' section of the app to match this message and the other 9 most recent commit messages")
                    RecentCommitRow(message: "Oct 5: Reduce debounce from 500ms/100ms to 50ms for rapid catch-up entry")
                    RecentCommitRow(message: "Oct 5: Fix Live Activity performance and reliability")
                    RecentCommitRow(message: "Oct 5: Add .gitignore for Xcode and Swift projects")
                    RecentCommitRow(message: "Oct 5: Move git repository to project root and add CLAUDE.md to version control")
                    RecentCommitRow(message: "Oct 4: debugging live activity not updating (or lagging)")
                    RecentCommitRow(message: "Oct 4: Fix game numbering in pyramid charts (S1G7→S1G9 bug)")
                    RecentCommitRow(message: "Oct 4: Prettify by-game charts")
                    RecentCommitRow(message: "Oct 4: still adding weatherkit (in progress; maybe waiting for apple developer account to update)")
                    RecentCommitRow(message: "Oct 4: Began process of adding WeatherKit, just renewed paid Apple Developer one-year membership. Also added neat current location when new match is started. Tiny map expands to show location of match.")
                }
                .font(.caption)
            } header: {
                Text("Recent Changes")
            }

            Section {
                Text("Thanks for trying this nascent experimental app! Future features might include some of:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("• Watch app -> as remote control for phone app (rquires watch<>phone connection)")
                    Text("• Watch app -> with \"offline mode\" ready, in case we lose connection to phone")
                    Text("• User logins")
                    Text("• Manage saved players")
                    Text("• Export (json/csv?)")
                    Text("• Screenshot for social media")
                    Text("• Subscribe to someone's match")
                    Text("• Shareable permalink for finished games")
                    Text("• View your stats over time (across games)")
                    Text("• View summary stats for any two players, across matches (e.g., are matches getting closer or one player now beating the other more often?)")
                    Text("• Add \"workout\" type tracking, to avoid the need to separately record workout in Workout App or Strava")
                    Text("• Overlay performance with heart rate")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } header: {
                Text("Upcoming Features")
            }
        }
        .listStyle(.insetGrouped)
    }

    @available(iOS 16.1, *)
    private func restartLiveActivity() {
        guard let match = viewModel.match else { return }

        let state = viewModel.derivedState
        let serverID = ScoreEngine.currentServerID(
            visiblePoints: Array(match.sortedPoints.prefix(viewModel.cursor)),
            p1: match.playerOne.id,
            p2: match.playerTwo.id,
            firstServerID: match.firstServerID
        )
        let serverName = (serverID == match.playerOne.id) ? match.playerOne.name : match.playerTwo.name

        liveActivityManager.startMatchActivity(
            match: match,
            serverName: serverName,
            derivedState: state
        )
    }
}

struct RecentCommitRow: View {
    let message: String
    private let maxLength = 70

    private var truncatedMessage: String {
        if message.count > maxLength {
            return String(message.prefix(maxLength)) + "..."
        }
        return message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(truncatedMessage)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SettingsView()
}
