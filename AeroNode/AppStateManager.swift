//
//  AppStateManager.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Foundation
import SwiftUI
import Combine

// Enum representing the different states of our app.
// Equatable allows SwiftUI to animate transitions between these states smoothly.
public enum AppState: Equatable {
    case loading
    case missingDocker
    case needsPull
    case readyToStart
    case running
    case error(message: String)
}

@MainActor
public class AppStateManager: ObservableObject {
    @Published public var currentState: AppState = .loading
    
    public let envManager: EnvironmentManager
    
    public init(envManager: EnvironmentManager) {
        self.envManager = envManager
    }
    
    // Evaluates the environment and decides which screen to show
    public func evaluateEnvironment() async {
        currentState = .loading
        
        await envManager.checkEnvironment()
        
        // Check if Docker is available and running
        if !envManager.isDockerInstalled || !envManager.isDockerRunning {
            currentState = .missingDocker
            return
        }
        
        // Case 1: Docker is fine, but repo is missing
        if !envManager.isRepoCloned {
            currentState = .needsPull
            return
        }
        
        // Case 2: Everything is ready
        currentState = .readyToStart
    }
    
    // Triggered when the user clicks "Download Project"
    public func downloadProject() async {
        do {
            try await envManager.pullOrUpdateRepo()
            await evaluateEnvironment() // Re-check after downloading
        } catch {
            currentState = .error(message: "Download failed: \(error.localizedDescription)")
        }
    }
    
    // Triggered when the user clicks "Start Project"
    public func startProject() async {
        do {
            try await envManager.startBackend()
            currentState = .running
        } catch {
            currentState = .error(message: "Startup failed: \(error.localizedDescription)")
        }
    }
}
