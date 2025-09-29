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
                    checkPendingActions()
                    setupDarwinNotificationListener()
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

    // Set up listener for widget extension Darwin notifications
    private func setupDarwinNotificationListener() {
        print("📡 Setting up Darwin notification listener for widget actions...")

        // Use a simpler approach - just register for the notification
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, name, _, _ in
                DispatchQueue.main.async {
                    // Post a local notification that our app can receive
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WidgetActionReceived"),
                        object: nil
                    )
                }
            },
            "com.tennis.tracker.widgetAction" as CFString,
            nil,
            .deliverImmediately
        )

        // Set up local notification observer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WidgetActionReceived"),
            object: nil,
            queue: .main
        ) { _ in
            self.handleWidgetNotification()
        }

        print("📡 ✅ Darwin notification listener set up successfully")
    }

    // Handle notifications from widget extension
    private func handleWidgetNotification() {
        print("📡 RECEIVED DARWIN NOTIFICATION from widget extension")
        checkPendingActions() // Process any pending actions
    }

    // Check for pending actions from Live Activity buttons
    private func checkPendingActions() {
        let timestamp = Date()
        print("🔍 CHECKING FOR PENDING ACTIONS [\(timestamp)]...")

        // TEST MECHANISM: Simulate a widget action for testing (remove this later)
        // Uncomment the lines below to test the notification flow without widget
        /*
        print("🧪 TEST: Simulating widget action for testing...")
        NotificationCenter.default.post(
            name: NSNotification.Name("RecordPointFromWidget"),
            object: nil,
            userInfo: ["pointType": "winner", "player": "Mark"]
        )
        print("🧪 TEST: Widget action simulation completed")
        */

        let defaults = UserDefaults(suiteName: "group.com.markmoriarty.apps.TennisTracker")
        print("🔍 UserDefaults created: \(defaults != nil ? "YES" : "NO")")

        // Always log all available keys for debugging
        if let allKeys = defaults?.dictionaryRepresentation().keys {
            let keyArray = Array(allKeys).sorted()
            print("🔍 ALL UserDefaults keys (\(keyArray.count)): \(keyArray)")
        } else {
            print("🔍 No UserDefaults keys found")
        }

        // Check specifically for pendingAction
        let pendingAction = defaults?.dictionary(forKey: "pendingAction")
        print("🔍 Direct pendingAction check: \(pendingAction != nil ? "FOUND" : "NOT FOUND")")

        if let actionData = pendingAction {
            print("🎯 PENDING ACTION DETECTED: \(actionData)")

            // Extract timestamp for tracking
            if let timestamp = actionData["timestamp"] as? Double {
                let actionDate = Date(timeIntervalSince1970: timestamp)
                let timeDiff = Date().timeIntervalSince(actionDate)
                print("🎯 Action timestamp: \(actionDate), age: \(timeDiff)s")
            }

            // Clear the action so it only processes once
            defaults?.removeObject(forKey: "pendingAction")
            defaults?.synchronize()
            print("🎯 Action cleared from UserDefaults")

            // Process the action
            if let action = actionData["action"] as? String,
               let pointType = actionData["pointType"] as? String,
               let player = actionData["player"] as? String,
               action == "recordPoint" {

                print("🎯 PROCESSING: \(pointType) for \(player)")

                // Post notification so PlayView can handle it
                print("🎯 Posting NotificationCenter notification...")
                NotificationCenter.default.post(
                    name: NSNotification.Name("RecordPointFromWidget"),
                    object: nil,
                    userInfo: ["pointType": pointType, "player": player]
                )
                print("🎯 ✅ Notification posted successfully")
            } else {
                print("❌ Failed to parse action data properly")
                print("❌ action='\(actionData["action"] ?? "nil")'")
                print("❌ pointType='\(actionData["pointType"] ?? "nil")'")
                print("❌ player='\(actionData["player"] ?? "nil")'")
            }
        } else {
            print("🔍 No pending actions found")
        }

        print("🔍 checkPendingActions completed [\(timestamp)]")
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