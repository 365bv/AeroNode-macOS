//
//  EnvironmentManager.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Foundation
import Combine

@MainActor
public class EnvironmentManager: ObservableObject {
    @Published public var isDockerInstalled: Bool = false
    @Published public var isDockerRunning: Bool = false
    @Published public var isRepoCloned: Bool = false
    @Published public var downloadProgress: Double = 0.0
    
    private let githubRepoURL = "https://github.com/365bv/iot-monitoring-diploma.git"
    
    // The folder name where the project will live
    private let repoName = "WindSimulatorCore"
    
    // Path inside ~/Library/Application Support/
    private var repoURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("com.vitaliibazavluk.AeroNode").appendingPathComponent(repoName)
    }
    
    public init() {
        // Create the application directory if it's the first time
        let appDir = repoURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
    }
    
    // Checks everything: Docker and Repo status
    public func checkEnvironment() async {
        await checkDocker()
        checkProjectRepo()
    }
    
    // Asks the system if Docker is alive, explicitly setting the PATH
    private func checkDocker() async {
        do {
            // Apps launched via Xcode don't inherit terminal PATH. We explicitly add standard Docker locations.
            let command = "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && docker info"
            let output = try await ShellManager.shared.run(command)
            isDockerInstalled = true
            isDockerRunning = !output.contains("Cannot connect to the Docker daemon") && !output.contains("error")
        } catch {
            isDockerInstalled = false
            isDockerRunning = false
        }
    }
    
    // Checks if the Git folder already exists locally
    private func checkProjectRepo() {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: repoURL.path, isDirectory: &isDirectory)
        isRepoCloned = exists && isDirectory.boolValue
    }
    
    // Executes 'git clone' or 'git pull'
    public func pullOrUpdateRepo() async throws {
        downloadProgress = 0.1
        
        if isRepoCloned {
            // Pull the latest changes if we already have it
            _ = try await ShellManager.shared.run("cd \"\(repoURL.path)\" && git pull")
        } else {
            // Clone from scratch if we don't
            _ = try await ShellManager.shared.run("cd \"\(repoURL.deletingLastPathComponent().path)\" && git clone \(githubRepoURL) \(repoName)")
        }
        
        downloadProgress = 1.0
        checkProjectRepo()
    }
    
    // Starts the Docker Compose stack
    public func startBackend() async throws {
        // Generate .env file based on your .env.example if it's missing
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
            try? defaultEnv.write(to: envFileURL, atomically: true, encoding: .utf8)
        }
        
        // Start Docker with the correct PATH
        let command = "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && cd \"\(repoURL.path)\" && docker-compose up -d"
        _ = try await ShellManager.shared.run(command)
    }
    
    
    public func updateTurbineCount(_ count: Int) async {
        // Формуємо правильний JSON для твого Python-скрипта
        let jsonPayload = "{\\\"count\\\": \(count)}"
        
        // Використовуємо docker-compose exec. Прапорець -T важливий,
        // щоб команда працювала у фоні без прив'язки до реального термінала (TTY).
        let command = """
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" && \
        cd "\(repoURL.path)" && \
        docker-compose exec -T mqtt_broker mosquitto_pub -t "sim/control/turbine_count" -m "\(jsonPayload)"
        """
        
        do {
            let output = try await ShellManager.shared.run(command)
            print("🚀 MQTT Sent successfully: \(jsonPayload)")
            if !output.isEmpty {
                print("Output: \(output)")
            }
        } catch {
            print("❌ Failed to send MQTT: \(error)")
        }
    }
    
    
        public func stopBackend() {
            let command = "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && cd \"\(repoURL.path)\" && docker-compose down"
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            try? process.run()
            process.waitUntilExit()
        }
}
