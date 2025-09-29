//
//  SettingsView.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings will go here.")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Thanks for trying this nascent experimental app! Future features might include some of:")
                .font(.subheadline)
                .fontWeight(.medium)

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

            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
