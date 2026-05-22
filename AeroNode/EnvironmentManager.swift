//
//  EnvironmentManager.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Combine
import Foundation

/// Manages the application's underlying dependencies, such as Docker availability and local git repositories.
@MainActor
public class EnvironmentManager: ObservableObject {
    @Published public var isDockerInstalled: Bool = false
    @Published public var isDockerRunning: Bool = false
    @Published public var isRepoCloned: Bool = false
    @Published public var downloadProgress: Double = 0.0

    private let githubRepoURL =
        "https://github.com/365bv/iot-monitoring-diploma.git"

    // The folder name where the project will live
    private let repoName = "WindSimulatorCore"

    // Path inside ~/Library/Application Support/
    private var repoURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("com.vitaliibazavluk.AeroNode")
            .appendingPathComponent(repoName)
    }

    public init() {
        // Create the application directory if it's the first time
        let appDir = repoURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(
                at: appDir,
                withIntermediateDirectories: true
            )
        }
    }

    /// Checks both Docker status and the local repository status.
    public func checkEnvironment() async {
        await checkDocker()
        checkProjectRepo()
    }

    // Asks the system if Docker is alive, explicitly setting the PATH
    private func checkDocker() async {
        do {
            // Apps launched via Xcode don't inherit terminal PATH. We explicitly add standard Docker locations.
            let command =
                "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && docker info"
            let output = try await ShellManager.shared.run(command)
            isDockerInstalled = true
            isDockerRunning =
                !output.contains("Cannot connect to the Docker daemon")
                && !output.contains("error")
        } catch {
            isDockerInstalled = false
            isDockerRunning = false
        }
    }

    /// Checks if the Git folder already exists locally.
    public func checkProjectRepo() {
        let gitFolder = repoURL.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: gitFolder.path,
            isDirectory: &isDirectory
        )

        isRepoCloned = exists && isDirectory.boolValue
    }

    /// Executes 'git clone' or 'git pull' specifically for the 'develop' branch.
    public func pullOrUpdateRepo() async throws {
        downloadProgress = 0.1

        // Explicitly check the repository state before acting
        checkProjectRepo()

        if isRepoCloned {
            print("🔄 Attempting to update existing repo on 'develop' branch...")
            let updateCommand = """
                export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" && \
                cd "\(repoURL.path)" && \
                git fetch origin && \
                git checkout -f develop && \
                git pull origin develop
                """
            _ = try await ShellManager.shared.run(updateCommand)
            print("✅ Repo successfully updated from 'develop' branch.")
        } else {
            print("📦 Folder missing or not a git repo. Cloning 'develop'...")
            // Clean up the directory before cloning to handle corrupted states
            try? FileManager.default.removeItem(at: repoURL)

            let cloneCommand = """
                export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" && \
                cd "\(repoURL.deletingLastPathComponent().path)" && \
                git clone -b develop \(githubRepoURL) \(repoName)
                """
            _ = try await ShellManager.shared.run(cloneCommand)
            print("✅ Repo successfully cloned (branch: develop).")
        }

        downloadProgress = 1.0
        checkProjectRepo()
    }

    /// Starts the Docker Compose stack for the IoT backend.
    public func startBackend() async throws {
        // Generate .env file based on the .env.example if it's missing
        let envFileURL = repoURL.appendingPathComponent(".env")
        if !FileManager.default.fileExists(atPath: envFileURL.path) {
            // Using the exact structure from the repository's .env.example
            // Note: COMPOSE_PROFILES is empty to run headless (native macOS app handles the UI)
            let defaultEnv = """
                # Configuration for the InfluxDB 2.0 Docker container and Python client

                # --- Compose Profiles ---
                # 'web' starts the dashboard, empty starts headless
                COMPOSE_PROFILES=

                # --- Turbine Simulation Settings ---
                INITIAL_TURBINE_COUNT=5

                # --- InfluxDB Settings ---
                # --- Login credentials for the UI & Python client ---
                INFLUX_USERNAME=admin
                INFLUX_PASSWORD=password
                INFLUX_TOKEN=secret-token

                # --- Names for Org & Bucket ---
                INFLUX_ORG=Turbine-Monitoring-Project
                INFLUX_BUCKET=turbine_data

                # --- MQTT Settings ---
                # Quality of Service level (0, 1, or 2).
                MQTT_QOS=0
                """
            try? defaultEnv.write(
                to: envFileURL,
                atomically: true,
                encoding: .utf8
            )
        }

        // Start Docker with the correct PATH
        let command =
            "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && cd \"\(repoURL.path)\" && docker-compose up -d"
        _ = try await ShellManager.shared.run(command)
    }

    /// Shuts down the Docker Compose stack in the background.
    public func stopBackend() {

        let targetPath = self.repoURL.path

        Task.detached(priority: .background) {
            let command =
                "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && cd \"\(targetPath)\" && docker-compose down"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            try? process.run()
            process.waitUntilExit()
            print("🛑 Docker cleanup finished in background.")
        }
    }

    /// Fetches the recent log tail for a specified Docker service.
    public func fetchLogs(for service: String) async -> String {
        let serviceArg = service == "All" ? "" : service
        let command = """
            export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" && \
            cd "\(repoURL.path)" && \
            docker-compose logs --tail=150 \(serviceArg)
            """

        do {
            let output = try await ShellManager.shared.run(command)
            return output.isEmpty ? "No logs available for \(service)." : output
        } catch {
            return "❌ Error fetching logs: \(error.localizedDescription)"
        }
    }
}
