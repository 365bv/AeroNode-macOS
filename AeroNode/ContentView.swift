//
//  ContentView.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import AppKit
import SwiftUI

/// The root view of the application that handles state-based routing.
public struct ContentView: View {
    @StateObject private var stateManager: AppStateManager

    init() {
        let env = EnvironmentManager()
        _stateManager = StateObject(
            wrappedValue: AppStateManager(envManager: env)
        )
    }

    public var body: some View {
        NavigationStack {
            Group {
                if stateManager.currentState == .running {
                    DashboardView()
                } else {
                    WelcomeView(stateManager: stateManager)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .task {
            await stateManager.evaluateEnvironment()
        }
    }
}

#Preview {
    ContentView()
}
