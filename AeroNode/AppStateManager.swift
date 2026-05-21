//
//  AppStateManager.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Combine
import Foundation
import SwiftUI

/// Represents the various lifecycle states of the application.
/// Equatable allows SwiftUI to animate transitions smoothly between these states.
public enum AppState: Equatable {
    case loading
    case missingDocker
    case needsPull
    case readyToStart
    case running
    case error(message: String)
}

/// Manages the global state and transitions of the AeroNode application.
@MainActor
public class AppStateManager: ObservableObject {
    /// The current state of the application.
    @Published public var currentState: AppState = .loading

    /// The environment manager for handling backend Docker services and git repositories.
    public let envManager: EnvironmentManager

    public init(envManager: EnvironmentManager) {
        self.envManager = envManager
    }

    /// Evaluates the current environment, checking Docker availability and the state of the local repository.
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
        do {
            print("⏳ Checking for backend updates on 'develop' branch...")
            try await envManager.pullOrUpdateRepo()

            currentState = .readyToStart
        } catch {
            print(
                "⚠️ Update check failed, but project folder exists. Proceeding with local version."
            )
            currentState = .readyToStart
        }
    }

    /// Triggers the download and setup of the underlying backend project.
    public func downloadProject() async {
        do {
            try await envManager.pullOrUpdateRepo()
            await evaluateEnvironment()  // Re-check after downloading
        } catch {
            currentState = .error(
                message: "Download failed: \(error.localizedDescription)"
            )
        }
    }

    /// Starts the IoT backend services.
    public func startProject() async {
        do {
            try await envManager.startBackend()
            currentState = .running
        } catch {
            currentState = .error(
                message: "Startup failed: \(error.localizedDescription)"
            )
        }
    }
}
