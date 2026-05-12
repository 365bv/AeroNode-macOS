//
//  DashboardViewModel.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Foundation
import Combine

@MainActor
public class DashboardViewModel: ObservableObject {
    @Published public var turbines: [Turbine] = []
    @Published public var selection: String? = "Overview"
    @Published public var activeCount: Double = 5.0
    
    private let envManager = EnvironmentManager()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        
        self.turbines = (1...24).map { Turbine(id: $0, isRunning: $0 <= 5, power: 0.0, temperature: 22.0) }
        
        
        $activeCount
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.syncWithBackend(Int(newValue))
            }
            .store(in: &cancellables)
    }

    private func syncWithBackend(_ count: Int) {
        // Оновлюємо внутрішній стан юнітів (колір крапок)
        for i in 0..<turbines.count {
            turbines[i].isRunning = turbines[i].id <= count
        }
        
        // Відправляємо команду в Docker у фоновому режимі
        Task {
            await envManager.updateTurbineCount(count)
        }
    }

    public func updateTurbineStates() {
        // Метод залишається для миттєвого відгуку UI (червоне/зелене)
        for i in 0..<turbines.count {
            turbines[i].isRunning = Double(turbines[i].id) <= activeCount
        }
    }
    
    public func stopAll() {
        activeCount = 0
        updateTurbineStates() // Оновиться миттєво через UI
    }
}
