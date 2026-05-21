//
//  DashboardViewModel.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Combine
import Foundation

/// A single data point representing telemetry from a specific wind turbine.
public struct TelemetryPoint: Identifiable {
    public let id = UUID()
    public let turbineId: String
    public let timestamp: Date
    public let powerOutput: Double
    public let gearboxTemp: Double
    public let rotorSpeed: Double
    public let windSpeed: Double
    public let latency: Double
}

/// The core view model managing the dashboard's state, including turbine states and telemetry data.
@MainActor
public class DashboardViewModel: ObservableObject {
    @Published public var turbines: [Turbine] = []
    @Published public var activeCount: Double = 5.0
    @Published public var qosLevel: Double = 0.0
    @Published public var currentQoS: String = "0"

    @Published public var telemetryData: [TelemetryPoint] = []
    @Published public var selectedTurbineFilter: String = "All"

    private let envManager = EnvironmentManager()
    private let mqttManager = MQTTManager()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.turbines = (1...100).map {
            Turbine(id: $0, isRunning: $0 <= 5, power: 0.0, temperature: 22.0)
        }

        // Observer for turbine count changes
        $activeCount
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }

                self.syncStates()

                if self.selectedTurbineFilter != "All" {
                    let idStr = self.selectedTurbineFilter.replacingOccurrences(
                        of: "WT-",
                        with: ""
                    )
                    if let id = Int(idStr), id > Int(newValue) {
                        self.selectedTurbineFilter = "All"
                    }
                }
            }
            .store(in: &cancellables)

        // Observer for QoS level changes
        $qosLevel
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.currentQoS = "\(Int(newValue))"
                self.syncStates()
            }
            .store(in: &cancellables)

        mqttManager.start()

        mqttManager.telemetrySubject
            .receive(on: RunLoop.main)
            .sink { [weak self] newPoint in
                guard let self = self else { return }

                // Append new telemetry point
                self.telemetryData.append(newPoint)

                // Remove data older than 60 seconds to manage memory
                let cutoff = Calendar.current.date(
                    byAdding: .second,
                    value: -60,
                    to: Date()
                )!
                self.telemetryData.removeAll { $0.timestamp < cutoff }
            }
            .store(in: &cancellables)
    }

    /// Synchronizes the local turbine states with the backend via MQTT.
    private func syncStates() {
        let count = Int(activeCount)
        let qos = Int(qosLevel)

        var updatedTurbines = turbines
        for i in 0..<updatedTurbines.count {
            updatedTurbines[i].isRunning = updatedTurbines[i].id <= count
        }
        turbines = updatedTurbines

        Task { await envManager.updateSystemState(count: count, qos: qos) }
    }

    /// Updates the local visual state of turbines based on the active count.
    public func updateTurbineStates() {
        var updatedTurbines = turbines
        for i in 0..<updatedTurbines.count {
            updatedTurbines[i].isRunning =
                Double(updatedTurbines[i].id) <= activeCount
        }
        turbines = updatedTurbines
    }

    /// Stops all active turbines and sets the active count to zero.
    public func stopAll() {
        activeCount = 0
        updateTurbineStates()
    }

}
