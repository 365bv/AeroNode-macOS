//
//  Turbine.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Foundation

public struct Turbine: Identifiable {
    public let id: Int
    public var isRunning: Bool
    public var power: Double
    public var temperature: Double
    
    
    public var statusColor: String {
        isRunning ? "green" : "red"
    }
}
