//
//  TennisTrackerApp.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import AppIntents

@main
struct TennisTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Player.self,
            Match.self,
            Point.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestNotificationPermissions()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func requestNotificationPermissions() {
        // Set delegate to show notifications even when app is in foreground
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("🎾 Notification permissions granted - Live Activities should work")
                } else {
                    print("❌ Notification permissions denied - Live Activities won't work")
                    if let error = error {
                        print("❌ Permission error: \(error)")
                    }
                }
            }
        }
    }

    // Send a local notification
    func sendGameNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("🔔 Notification sent: \(title)")
            }
        }
    }
}

// Notification delegate to show notifications even when app is in foreground
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}