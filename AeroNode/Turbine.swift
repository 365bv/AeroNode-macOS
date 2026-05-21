//
//  Turbine.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Foundation

/// Represents the basic operational state of a single wind turbine unit.
public struct Turbine: Identifiable {
    public let id: Int
    public var isRunning: Bool
    public var power: Double
    public var temperature: Double

    /// A helper property for the UI layer to determine the status color indicator.
    public var statusColor: String {
        isRunning ? "green" : "red"
    }
}
