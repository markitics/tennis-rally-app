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
                Text("Thanks for trying this nascent experimental app! Future features might include some of:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("• Manage saved players")
                    Text("• Default first server setting")
                    Text("• Scoring options")
                    Text("• Export/import JSON/CSV")
                    Text("• iCloud toggle")
                    Text("• Screenshot for social media")
                    Text("• User logins")
                    Text("• Subscribe to someone's match")
                    Text("• permalink for finished games")
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

#Preview {
    SettingsView()
}
