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
                .onOpenURL { url in
                    handleURL(url)
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

    // Handle URL schemes from Live Activity buttons
    private func handleURL(_ url: URL) {
        let timestamp = Date()
        print("🔗 URL RECEIVED [\(timestamp)]: \(url)")

        guard url.scheme == "tennistracker" else {
            print("❌ Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }

        print("🔗 Processing tennistracker URL with host: '\(url.host ?? "nil")'")

        // Check if this is a silent action (from Live Activity)
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let isSilent = urlComponents?.queryItems?.contains { $0.name == "silent" && $0.value == "true" } ?? false

        if isSilent {
            print("🔇 SILENT ACTION: Processing Live Activity button press without UI focus")
        }

        switch url.host {
        case "winner":
            print("🏆 Winner button pressed from Live Activity")
            print("🏆 Posting NotificationCenter notification for winner...")
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: ["pointType": "winner", "player": "Mark"]
            )
            print("🏆 ✅ Winner notification posted successfully")
        case "error":
            print("🙈 Error button pressed from Live Activity")
            print("🙈 Posting NotificationCenter notification for error...")
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordPointFromWidget"),
                object: nil,
                userInfo: ["pointType": "unforcedError", "player": "Mark"]
            )
            print("🙈 ✅ Error notification posted successfully")
        default:
            print("❓ Unknown URL action: '\(url.host ?? "nil")'")
        }

        // For silent actions, send the app to background after a brief delay
        if isSilent {
            print("🔇 SILENT: Scheduling app backgrounding...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔇 SILENT: Sending app to background...")
                // Note: In iOS, apps can't force themselves to background
                // But we can minimize UI disruption by not showing alerts or navigation
            }
        }

        print("🔗 URL handling completed [\(timestamp)]")
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