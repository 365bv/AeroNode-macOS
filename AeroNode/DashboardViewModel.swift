//
//  DashboardViewModel.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Combine
import Foundation
import Observation
import SwiftUI

/// A single data point representing telemetry from a specific wind turbine.
public struct TelemetryPoint: Identifiable, Sendable {
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
@Observable
public class DashboardViewModel {
    public var turbines: [Turbine] = []

    @ObservationIgnored private var countTask: Task<Void, Never>?
    public var activeCount: Double = 5.0 {
        didSet {

            guard activeCount != oldValue else { return }

            countTask?.cancel()
            countTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }

                updateTurbineStates()

                if selectedTurbineFilter != "All" {
                    let idStr = selectedTurbineFilter.replacingOccurrences(
                        of: "WT-",
                        with: ""
                    )
                    if let id = Int(idStr), id > Int(activeCount) {
                        selectedTurbineFilter = "All"
                    }
                }
            }
        }
    }

    @ObservationIgnored private var qosTask: Task<Void, Never>?
    public var qosLevel: Double = 0.0 {
        didSet {
            guard qosLevel != oldValue else { return }
            currentQoS = "\(Int(qosLevel))"

            qosTask?.cancel()
            qosTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                updateTurbineStates()
            }
        }
    }

    public var currentQoS: String = "0"
    public var telemetryData: [TelemetryPoint] = []
    public var selectedTurbineFilter: String = "All"

    @ObservationIgnored private let envManager = EnvironmentManager()
    @ObservationIgnored private let mqttManager = MQTTManager()
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    public init() {
        self.turbines = (1...100).map {
            Turbine(id: $0, isRunning: $0 <= 5, power: 0.0, temperature: 22.0)
        }

        mqttManager.start()

        mqttManager.telemetrySubject
            .collect(.byTime(RunLoop.main, .milliseconds(250)))
            .sink { [weak self] batchedPoints in

                guard let self, !batchedPoints.isEmpty else { return }

                self.telemetryData.append(contentsOf: batchedPoints)

                if self.telemetryData.count > 2000 {
                    let excess = self.telemetryData.count - 2000
                    self.telemetryData.removeFirst(excess)
                }
            }
            .store(in: &cancellables)
    }

    public func updateTurbineStates() {
        self.turbines = (1...100).map {
            Turbine(
                id: $0,
                isRunning: $0 <= Int(activeCount),
                power: 0.0,
                temperature: 22.0
            )
        }

        mqttManager.sendControlCommand(
            count: Int(activeCount),
            qos: Int(qosLevel)
        )
    }

    public func stopAll() {
        activeCount = 0
        countTask?.cancel()
        updateTurbineStates()
    }
}
