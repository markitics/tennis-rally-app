//
//  TennisTrackerWidget.swift
//  TennisTrackerWidget
//
//  Enhanced Live Activity with score and buttons
//

import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@available(iOS 16.1, *)
struct TennisMatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TennisMatchAttributes.self) { context in
            // Lock screen/banner area - rich content
            VStack(spacing: 12) {
                // Header with players
                HStack {
                    Text(context.state.playerOneName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("vs")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context.state.playerTwoName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                // Current score display
                Text(context.state.currentScore)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()

                // Server indicator
                Text("\(context.state.serverName) serving")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Action buttons row
                HStack(spacing: 16) {
                    Button(intent: WinnerIntent()) {
                        VStack(spacing: 4) {
                            Text("🏆")
                                .font(.title3)
                            Text("Winner")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(intent: UnforcedErrorIntent()) {
                        VStack(spacing: 4) {
                            Text("🙈")
                                .font(.title3)
                            Text("Error")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
            .padding()
        } dynamicIsland: { context in
            // Minimal Dynamic Island for devices that have it
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text("\(context.state.playerOneName) vs \(context.state.playerTwoName)")
                            .font(.caption)
                        Text(context.state.currentScore)
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Text("🎾")
            } compactTrailing: {
                Text("LIVE")
            } minimal: {
                Text("🎾")
            }
        }
    }
}