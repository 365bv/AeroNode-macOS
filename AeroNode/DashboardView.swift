//
//  DashboardView.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import SwiftUI

/// The main dashboard view providing navigation and high-level controls for the IoT monitoring system.
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedTab: String = "Overview"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Monitor") {
                    Label("Overview", systemImage: "chart.bar.fill").tag(
                        "Overview"
                    )
                    Label("Telemetry", systemImage: "wave.3.right").tag(
                        "Telemetry"
                    )
                }

                Section("System") {
                    Label("Docker Logs", systemImage: "terminal.fill").tag(
                        "Logs"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Control Center")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Active Units:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(viewModel.activeCount))")
                                .font(
                                    .system(.subheadline, design: .monospaced)
                                )
                                .bold()
                                .foregroundStyle(
                                    viewModel.activeCount > 0 ? .green : .red
                                )
                        }

                        Slider(
                            value: $viewModel.activeCount,
                            in: 0...100,
                            step: 5
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("QoS Level:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(viewModel.qosLevel))")
                                .font(
                                    .system(.subheadline, design: .monospaced)
                                )
                                .bold()
                                .foregroundStyle(.purple)
                        }

                        Slider(value: $viewModel.qosLevel, in: 0...2, step: 1)

                        if viewModel.qosLevel > 0 {
                            Text("Higher QoS increases latency")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    if viewModel.activeCount == 0 {
                        Text("System on Standby")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                            .transition(.opacity)
                    }

                    Button(role: .destructive) {
                        viewModel.stopAll()
                    } label: {
                        Label("Global Stop", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.vertical, 8)
                .animation(.spring(), value: viewModel.activeCount)
            }
            .listStyle(.sidebar)
            .navigationTitle("AeroNode")
        } detail: {
            ZStack {
                adaptiveBackground

                if selectedTab == "Overview" {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 25) {
                            headerSection

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 130))],
                                spacing: 20
                            ) {
                                ForEach(viewModel.turbines) { turbine in
                                    TurbineNode(turbine: turbine)
                                }
                            }
                            .padding()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
                    .id("OverviewScreen")

                } else if selectedTab == "Telemetry" {
                    TelemetryView(viewModel: viewModel)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.98))
                        )
                        .zIndex(2)
                        .id("TelemetryScreen")

                } else if selectedTab == "Logs" {
                    DockerLogsView()
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.98))
                        )
                        .zIndex(3)
                        .id("LogsScreen")

                } else {
                    Text("Select a section from the sidebar")
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .zIndex(0)
                        .id("PlaceholderScreen")
                }
            }

            .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
    }

    var adaptiveBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: colorScheme == .dark
                    ? [
                        .black, .black, .blue.opacity(0.2),
                        .black, .indigo.opacity(0.2), .black,
                        .blue.opacity(0.1), .black, .black,
                    ]
                    : [
                        .white, .white, .blue.opacity(0.1),
                        .white, .cyan.opacity(0.1), .white,
                        .blue.opacity(0.05), .white, .white,
                    ]
            )
            .ignoresSafeArea()
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Turbine Matrix")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Real-time cluster monitoring")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 30)
    }
}

/// A visual representation of a single wind turbine unit.
struct TurbineNode: View {
    let turbine: Turbine

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(.primary.opacity(0.1), lineWidth: 0.5)
                    )

                Circle()
                    .fill(turbine.isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    .shadow(
                        color: (turbine.isRunning ? Color.green : Color.red)
                            .opacity(0.6),
                        radius: 6
                    )
            }

            Text("Unit \(String(format: "%02d", turbine.id))")
                .font(.system(.caption2, design: .monospaced))
                .bold()
        }
        .frame(width: 110, height: 100)
        .background(.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
