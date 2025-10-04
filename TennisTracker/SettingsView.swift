//
//  SettingsView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true

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
}

#Preview {
    SettingsView()
}
