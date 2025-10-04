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
            // Lock screen - 3 EQUAL COLUMNS: Score info + Mark wins column + Jeff wins column
            HStack(spacing: 6) {
                // COLUMN 1 (33%): Score info
                VStack(alignment: .leading, spacing: 4) {
                    // Current set games score ONLY (e.g., "3-2")
                    Text(context.state.setsAndGamesScore.components(separatedBy: ", ").last ?? "0-0")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Server status - at 0-0 show who's about to serve, otherwise show who's serving
                    let isGameStart = context.state.inGameScoreP1 == "0" && context.state.inGameScoreP2 == "0"
                    if isGameStart {
                        let otherPlayer = context.state.serverName == context.state.playerOneName ? context.state.playerTwoName : context.state.playerOneName
                        Text(otherPlayer + "\nto serve")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(context.state.serverName + "\nserving")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    // Current game score - one size smaller (title2 instead of title)
                    HStack(spacing: 2) {
                        Text(context.state.inGameScoreP1)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("-")
                            .font(.caption)
                        Text(context.state.inGameScoreP2)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)

                // COLUMN 2 (33%): Mark wins point
                VStack(spacing: 8) {
                    // Row 1: Serve outcome (conditional)
                    if context.state.serverName == "Mark" {
                        Button(intent: AceIntent()) {
                            Text("🎾 M ace")
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Button(intent: DoubleFaultIntent()) {
                            Text("❌ Dbl fault")
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    // Row 2: Mark winner
                    Button(intent: WinnerIntent()) {
                        VStack(spacing: 2) {
                            Text("🏆").font(.title3)
                            Text("M Win").font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    // Row 3: Jeff error
                    Button(intent: JeffErrorIntent()) {
                        VStack(spacing: 2) {
                            Text("🙈").font(.title3)
                            Text("J Err").font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .frame(maxWidth: .infinity)

                // COLUMN 3 (33%): Jeff wins point
                VStack(spacing: 8) {
                    // Row 1: Serve outcome (conditional)
                    if context.state.serverName == "Jeff" {
                        Button(intent: AceIntent()) {
                            Text("🎾 J ace")
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Button(intent: DoubleFaultIntent()) {
                            Text("❌ Dbl fault")
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    // Row 2: Jeff winner
                    Button(intent: JeffWinnerIntent()) {
                        VStack(spacing: 2) {
                            Text("🏆").font(.title3)
                            Text("J Win").font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    // Row 3: Mark error
                    Button(intent: UnforcedErrorIntent()) {
                        VStack(spacing: 2) {
                            Text("🙈").font(.title3)
                            Text("M Err").font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .frame(height: 180) // Try to claim ~180pts - push iOS limits!
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
