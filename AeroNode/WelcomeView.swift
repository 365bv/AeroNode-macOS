//
//  WelcomeView.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import SwiftUI

public struct WelcomeView: View {
    @ObservedObject public var stateManager: AppStateManager
    @Environment(\.colorScheme) var colorScheme
    
    public var body: some View {

        NavigationStack {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    headerIcon
                    
                    VStack(spacing: 12) {
                        Text("AeroNode")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .tracking(-1)
                        
                        Text("Next-gen IIoT Control Center")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    mainActionCard
                        .frame(width: 400)
                    
                    Spacer()
                }
                .padding(60)
            }
            
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("")
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // --- Components ---
    
    private var headerIcon: some View {
        ZStack {
            Circle()
                .fill(.blue.gradient)
                .frame(width: 100, height: 100)
                .blur(radius: 30)
                .opacity(0.4)
            
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.primary)
                .symbolEffect(.bounce, value: stateManager.currentState)
        }
    }
    
    private var mainActionCard: some View {
        VStack(spacing: 24) {
            switch stateManager.currentState {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                Text("Analyzing system...")
                
            case .missingDocker:
                statusView(icon: "exclamationmark.octagon.fill", color: .red, title: "Docker Required", message: "Please start Docker Desktop to proceed.")
                
            case .needsPull:
                VStack(spacing: 16) {
                    statusView(icon: "arrow.down.circle.fill", color: .blue, title: "Engine Missing", message: "Ready to download the simulation core.")
                    Button("Initialize Setup") {
                        Task { await stateManager.downloadProject() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
            case .readyToStart:
                VStack(spacing: 16) {
                    statusView(icon: "checkmark.circle.fill", color: .green, title: "System Ready", message: "All components are verified and cached.")
                    Button("Launch AeroNode") {
                        Task { await stateManager.startProject() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                }
                
            case .running:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Orchestrating containers...")
                }
                
            case .error(let message):
                statusView(icon: "xmark.shield.fill", color: .orange, title: "System Error", message: message)
            }
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func statusView(icon: String, color: Color, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
