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
//public class DashboardViewModel: ObservableObject {
//    @Published public var turbines: [Turbine] = []
//    @Published public var activeCount: Double = 5.0
//    @Published public var qosLevel: Double = 0.0
//    @Published public var currentQoS: String = "0"
//
//    @Published public var telemetryData: [TelemetryPoint] = []
//    @Published public var selectedTurbineFilter: String = "All"
//
//    private let envManager = EnvironmentManager()
//    private let mqttManager = MQTTManager()
//    private var cancellables = Set<AnyCancellable>()
//
//    public init() {
//        self.turbines = (1...100).map {
//            Turbine(id: $0, isRunning: $0 <= 5, power: 0.0, temperature: 22.0)
//        }
//
//        // Observer for turbine count changes
//        $activeCount
//            .removeDuplicates()
//            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
//            .sink { [weak self] newValue in
//                guard let self = self else { return }
//
//                self.updateTurbineStates()
//
//                if self.selectedTurbineFilter != "All" {
//                    let idStr = self.selectedTurbineFilter.replacingOccurrences(
//                        of: "WT-",
//                        with: ""
//                    )
//                    if let id = Int(idStr), id > Int(newValue) {
//                        self.selectedTurbineFilter = "All"
//                    }
//                }
//            }
//            .store(in: &cancellables)
//
//        // Observer for QoS level changes
//        $qosLevel
//            .removeDuplicates()
//            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
//            .sink { [weak self] newValue in
//                guard let self = self else { return }
//                self.currentQoS = "\(Int(newValue))"
//
//                self.updateTurbineStates()
//            }
//            .store(in: &cancellables)
//
//        mqttManager.start()
//
//        mqttManager.telemetrySubject
//            .receive(on: RunLoop.main)
//            .sink { [weak self] newPoint in
//                guard let self = self else { return }
//
//                self.telemetryData.append(newPoint)
//
//                if self.telemetryData.count > 2000 {
//
//                    self.telemetryData.removeFirst(500)
//                }
//            }
//            .store(in: &cancellables)
//    }
//
//    /// Updates the local visual state of turbines based on the active count.
//    public func updateTurbineStates() {
//        self.turbines = (1...100).map {
//            Turbine(
//                id: $0,
//                isRunning: $0 <= Int(activeCount),
//                power: 0.0,
//                temperature: 22.0
//            )
//        }
//
//        mqttManager.sendControlCommand(
//            count: Int(activeCount),
//            qos: Int(qosLevel)
//        )
//    }
//
//    /// Stops all active turbines and sets the active count to zero.
//    public func stopAll() {
//        activeCount = 0
//        updateTurbineStates()
//    }
//
//}
