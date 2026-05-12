//
//  AeroNodeApp.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        let env = EnvironmentManager()
        print("Cleaning up Docker containers...")
        env.stopBackend()
    }
}

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
