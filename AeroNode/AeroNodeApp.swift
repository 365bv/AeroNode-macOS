//
//  AeroNodeApp.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import SwiftUI
import UserNotifications

/// The main application delegate for managing lifecycle events and notifications.
class AppDelegate: NSObject, NSApplicationDelegate,
    UNUserNotificationCenterDelegate
{

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) {
            granted,
            error in
            if granted {
                print("✅ Notifications permission granted.")
            } else if let error = error {
                print("❌ Notifications error: \(error.localizedDescription)")
            }
        }
    }

    // Allow notifications to be shown even if the application is active and in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func applicationWillTerminate(_ notification: Notification) {
        let env = EnvironmentManager()
        print("Cleaning up Docker containers...")
        env.stopBackend()
    }
}

/// The main entry point for the AeroNode macOS application.
@main
struct AeroNodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
    }
}
