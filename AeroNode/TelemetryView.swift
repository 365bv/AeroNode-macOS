//
//  TelemetryView.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Charts
import SwiftUI

/// A view responsible for rendering real-time telemetry charts for the turbine cluster.
struct TelemetryView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var turbineOptions: [String] {
        var options = ["All"]
        let activeUnits = Int(viewModel.activeCount)
        // Prevent crash if activeUnits is zero
        if activeUnits > 0 {
            options.append(
                contentsOf: (1...activeUnits).map {
                    String(format: "WT-%02d", $0)
                }
            )
        }
        return options
    }

    var chartData: [TelemetryPoint] {
        if viewModel.selectedTurbineFilter == "All" {
            // Group all data points by their timestamp down to the second
            let grouped = Dictionary(
                grouping: viewModel.telemetryData,
                by: { $0.timestamp }
            )

            return grouped.map { (time, points) in
                // Aggregate data for the "All" view mode

                // Total Power Output of the farm
                let totalPower = points.map(\.powerOutput).reduce(0, +)

                // Critical limit monitoring: maximum gearbox temperature
                let maxTemp = points.map(\.gearboxTemp).max() ?? 0

                // Gust detection: maximum wind speed
                let maxWind = points.map(\.windSpeed).max() ?? 0

                // Maximum rotor speed across all turbines
                let maxRotor = points.map(\.rotorSpeed).max() ?? 0

                // Worst-case scenario detection: maximum network latency
                let maxLatency = points.map(\.latency).max() ?? 0

                return TelemetryPoint(
                    turbineId: "All",
                    timestamp: time,
                    powerOutput: totalPower,
                    gearboxTemp: maxTemp,
                    rotorSpeed: maxRotor,
                    windSpeed: maxWind,
                    latency: maxLatency
                )
            }.sorted(by: { $0.timestamp < $1.timestamp })
        } else {
            return viewModel.telemetryData
                .filter { $0.turbineId == viewModel.selectedTurbineFilter }
                .sorted(by: { $0.timestamp < $1.timestamp })
        }
    }

    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Telemetry")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                    Text("Real-time stream from MQTT broker")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Source", selection: $viewModel.selectedTurbineFilter) {
                    ForEach(turbineOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.top, 30)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {

                    chartCard(
                        title: viewModel.selectedTurbineFilter == "All"
                            ? "Total Power Output (kW)" : "Power Output (kW)",
                        color: .green
                    ) {
                        Chart(chartData) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("kW", point.powerOutput)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.green.gradient)

                            AreaMark(
                                x: .value("Time", point.timestamp),
                                y: .value("kW", point.powerOutput)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }

                    chartCard(title: "Wind Speed (m/s)", color: .cyan) {
                        Chart(chartData) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("m/s", point.windSpeed)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.cyan.gradient)
                        }
                    }

                    chartCard(
                        title: viewModel.selectedTurbineFilter == "All"
                            ? "Max Gearbox Temperature (°C)"
                            : "Gearbox Temperature (°C)",
                        color: .orange
                    ) {
                        Chart(chartData) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("°C", point.gearboxTemp)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.orange.gradient)
                        }
                    }

                    chartCard(title: "Rotor Speed (RPM)", color: .blue) {
                        Chart(chartData) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("RPM", point.rotorSpeed)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }

                    // Keep zero-baseline for latency to ensure the bar chart renders correctly
                    chartCard(
                        title:
                            "Data Pipeline Latency (ms) — (QoS=\(viewModel.currentQoS))",
                        color: .purple,
                        forceZero: true
                    ) {
                        Chart(chartData) { point in
                            BarMark(
                                x: .value("Time", point.timestamp),
                                y: .value("ms", point.latency)
                            )
                            .foregroundStyle(Color.purple.gradient)
                        }
                    }
                }
                .padding()
            }
        }
    }

    // --- Helper Component for Glass Cards ---
    @ViewBuilder
    private func chartCard<Content: View>(
        title: String,
        color: Color,
        forceZero: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.bold())
            }

            content()
                // Disable mandatory zero baseline to allow charts to dynamically zoom into actual data variance
                .chartYScale(domain: .automatic(includesZero: forceZero))
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(
                            stroke: StrokeStyle(lineWidth: 0.5, dash: [4])
                        )
                        AxisTick()
                        AxisValueLabel(format: .dateTime.minute().second())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(
                            stroke: StrokeStyle(lineWidth: 0.5, dash: [4])
                        )
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
