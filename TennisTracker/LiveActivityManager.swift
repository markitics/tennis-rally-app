//
//  LiveActivityManager.swift
//  TennisTracker
//
//  Manages Live Activities for tennis matches
//

import Foundation
import ActivityKit
import SwiftUI
import Combine

@available(iOS 16.1, *)
class LiveActivityManager: ObservableObject {
    @Published var hasActiveActivity: Bool = false
    private var currentActivity: Activity<TennisMatchAttributes>?

    // Start a Live Activity for a tennis match
    func startMatchActivity(match: Match, serverName: String, currentScore: String) {
        // Check if Live Activities are available and enabled
        let authInfo = ActivityAuthorizationInfo()
        print("🎾 Live Activities Auth Status: \(authInfo.areActivitiesEnabled)")
        print("🎾 Activity authorization info: \(authInfo)")
        print("🎾 Attempting to start Live Activity with players: \(match.playerOne.name) vs \(match.playerTwo.name)")

        guard authInfo.areActivitiesEnabled else {
            print("❌ Live Activities are not available or enabled")
            return
        }

        // End any existing activity first
        endMatchActivity()

        // Also end any other active activities that might exist (e.g., if user dismissed but we lost track)
        Task {
            for activity in Activity<TennisMatchAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            // Now start the new activity after cleanup
            let attributes = TennisMatchAttributes(
                matchId: match.id.uuidString,
                startTime: match.matchDate
            )

            let initialState = TennisMatchAttributes.ContentState(
                playerOneName: match.playerOne.name,
                playerTwoName: match.playerTwo.name,
                currentScore: currentScore,
                serverName: serverName,
                matchStatus: "In Progress",
                lastUpdated: Date()
            )

            do {
                print("🎾 Requesting Live Activity with attributes: \(attributes)")
                print("🎾 Initial state: \(initialState)")

                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: nil),
                    pushType: nil
                )

                await MainActor.run {
                    self.currentActivity = activity
                    self.hasActiveActivity = true
                }
                print("🎾 Live Activity started for match: \(match.playerOne.name) vs \(match.playerTwo.name)")
                print("🎾 Activity created with ID: \(activity.id)")
                print("🎾 Activity initial state: \(activity.activityState)")

            } catch {
                print("❌ Failed to start Live Activity: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        }
    }

    // Update the Live Activity with new score
    func updateMatchActivity(currentScore: String, serverName: String) {
        print("🎾 Attempting to update Live Activity: \(currentScore)")
        print("🎾 Current activity exists: \(currentActivity != nil)")
        print("🎾 Current activity ID: \(currentActivity?.id ?? "none")")

        guard let activity = currentActivity else {
            print("❌ No active Live Activity to update")
            return
        }

        let updatedState = TennisMatchAttributes.ContentState(
            playerOneName: activity.content.state.playerOneName,
            playerTwoName: activity.content.state.playerTwoName,
            currentScore: currentScore,
            serverName: serverName,
            matchStatus: "In Progress",
            lastUpdated: Date()
        )

        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
            print("🎾 Live Activity updated: \(currentScore)")

            // Debug: Check current activity status
            print("🎾 Activity state: \(activity.activityState)")
            print("🎾 Activity ID: \(activity.id)")

            // Check all active activities
            let allActivities = Activity<TennisMatchAttributes>.activities
            print("🎾 Total active activities: \(allActivities.count)")
        }
    }

    // End the Live Activity when match is completed
    func endMatchActivity(finalScore: String? = nil) {
        guard let activity = currentActivity else { return }

        let finalState = TennisMatchAttributes.ContentState(
            playerOneName: activity.content.state.playerOneName,
            playerTwoName: activity.content.state.playerTwoName,
            currentScore: finalScore ?? activity.content.state.currentScore,
            serverName: activity.content.state.serverName,
            matchStatus: "Completed",
            lastUpdated: Date()
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .default)
            print("🎾 Live Activity ended")
        }

        currentActivity = nil
        hasActiveActivity = false
    }
}