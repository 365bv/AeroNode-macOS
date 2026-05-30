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
    @Bindable var viewModel: DashboardViewModel

    var turbineOptions: [String] {
        var options = ["All"]
        let activeUnits = Int(viewModel.activeCount)
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
            let grouped = Dictionary(
                grouping: viewModel.telemetryData,
                by: { $0.timestamp }
            )

            return grouped.map { (time, points) in
                let totalPower = points.map(\.powerOutput).reduce(0, +)
                let maxTemp = points.map(\.gearboxTemp).max() ?? 0
                let maxWind = points.map(\.windSpeed).max() ?? 0
                let maxRotor = points.map(\.rotorSpeed).max() ?? 0
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
        GridItem(.flexible(), spacing: 20)
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

            ScrollView {
                LazyVGrid(columns: columns, spacing: 30) {

                    InteractiveChartCard(
                        title: viewModel.selectedTurbineFilter == "All"
                            ? "Total Power Output" : "Power Output",
                        unit: "kW",
                        color: .green,
                        data: chartData,
                        valuePath: \.powerOutput
                    ) {
                        ForEach(chartData) { point in
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

                    InteractiveChartCard(
                        title: "Wind Speed",
                        unit: "m/s",
                        color: .cyan,
                        data: chartData,
                        valuePath: \.windSpeed
                    ) {
                        ForEach(chartData) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("m/s", point.windSpeed)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.cyan.gradient)
                        }
                    }

                    InteractiveChartCard(
                        title: viewModel.selectedTurbineFilter == "All"
                            ? "Max Gearbox Temperature" : "Gearbox Temperature",
                        unit: "°C",
                        color: .orange,
                        data: chartData,
                        valuePath: \.gearboxTemp
                    ) {
                        ForEach(chartData) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("°C", point.gearboxTemp)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.orange.gradient)
                        }
                    }

                    InteractiveChartCard(
                        title: "Rotor Speed",
                        unit: "RPM",
                        color: .blue,
                        data: chartData,
                        valuePath: \.rotorSpeed
                    ) {
                        ForEach(chartData) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("RPM", point.rotorSpeed)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }

                    InteractiveChartCard(
                        title:
                            "Data Pipeline Latency (QoS=\(viewModel.currentQoS))",
                        unit: "ms",
                        color: .purple,
                        data: chartData,
                        valuePath: \.latency,
                        forceZero: true
                    ) {
                        ForEach(chartData) { point in
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
}

struct InteractiveChartCard<Content: ChartContent>: View {
    let title: String
    let unit: String
    let color: Color
    let data: [TelemetryPoint]
    let valuePath: KeyPath<TelemetryPoint, Double>
    let forceZero: Bool
    @ChartContentBuilder let content: () -> Content

    @State private var visibleRange: TimeInterval = 30.0
    @State private var baseRange: TimeInterval = 30.0
    @State private var selectedDate: Date?

    @State private var scrollPosition: Date = Date()
    @State private var isInitialized: Bool = false

    init(
        title: String,
        unit: String,
        color: Color,
        data: [TelemetryPoint],
        valuePath: KeyPath<TelemetryPoint, Double>,
        forceZero: Bool = false,
        @ChartContentBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.unit = unit
        self.color = color
        self.data = data
        self.valuePath = valuePath
        self.forceZero = forceZero
        self.content = content
    }

    var rightPadding: TimeInterval {
        visibleRange * 0.1
    }

    var selectedPoint: TelemetryPoint? {
        guard let selectedDate else { return nil }
        return data.min(by: {
            abs($0.timestamp.distance(to: selectedDate))
                < abs($1.timestamp.distance(to: selectedDate))
        })
    }

    var isDetachedFromLive: Bool {
        guard let latest = data.last?.timestamp else { return false }
        let rightEdge = scrollPosition.addingTimeInterval(visibleRange)
        return latest.timeIntervalSince(rightEdge) > -(rightPadding * 0.5)
    }

    var dynamicXDomain: ClosedRange<Date> {
        let first = data.first?.timestamp ?? Date()
        let last = data.last?.timestamp ?? Date()

        return first...last.addingTimeInterval(rightPadding)
    }

    var dynamicYDomain: ClosedRange<Double> {
        let start = scrollPosition
        let end = start.addingTimeInterval(visibleRange)
        var visiblePoints = data.filter {
            $0.timestamp >= start && $0.timestamp <= end
        }

        if visiblePoints.isEmpty {
            let fallbackEnd = data.last?.timestamp ?? Date()
            let fallbackStart = fallbackEnd.addingTimeInterval(-visibleRange)
            visiblePoints = data.filter {
                $0.timestamp >= fallbackStart && $0.timestamp <= fallbackEnd
            }
        }

        guard !visiblePoints.isEmpty else {
            return forceZero ? 0...10 : -10...10
        }

        let minVal = visiblePoints.map { $0[keyPath: valuePath] }.min() ?? 0.0
        let maxVal = visiblePoints.map { $0[keyPath: valuePath] }.max() ?? 10.0

        let padding = (maxVal - minVal) * 0.15
        let lowerBound = forceZero ? 0.0 : (minVal - padding)
        let upperBound = max(lowerBound + 0.1, maxVal + padding)

        return lowerBound...upperBound
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.bold())

                if isDetachedFromLive {
                    Button {
                        withAnimation(
                            .spring(response: 0.3, dampingFraction: 0.8)
                        ) {
                            if let latest = data.last?.timestamp {
                                scrollPosition = latest.addingTimeInterval(
                                    rightPadding - visibleRange
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                            Text("Live")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if let point = selectedPoint {
                    Text(
                        "\(point[keyPath: valuePath], specifier: "%.1f") \(unit)"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Chart {
                content()

                if let point = selectedPoint {
                    RuleMark(x: .value("Selected", point.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(color.opacity(0.8))
                        .annotation(
                            position: .top,
                            overflowResolution: .init(
                                x: .fit(to: .chart),
                                y: .fit(to: .chart)
                            )
                        ) {
                            VStack(alignment: .center, spacing: 2) {
                                Text(
                                    point.timestamp,
                                    format: .dateTime.hour().minute().second()
                                )
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                Text(
                                    "\(point[keyPath: valuePath], specifier: "%.1f") \(unit)"
                                )
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(color)
                            }
                            .padding(6)
                            .background(.thickMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 3)
                        }
                }
            }
            .animation(.none, value: data.count)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleRange)
            .chartScrollPosition(x: $scrollPosition)
            .chartXScale(domain: dynamicXDomain)
            .chartYScale(domain: dynamicYDomain)
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    AxisTick()
                    AxisValueLabel(format: .dateTime.minute().second())
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .onChange(of: data.last?.timestamp) { oldTimestamp, newTimestamp in
                guard let latest = newTimestamp else { return }

                if !isInitialized {
                    scrollPosition = latest.addingTimeInterval(
                        rightPadding - visibleRange
                    )
                    isInitialized = true
                    return
                }

                let rightEdge = scrollPosition.addingTimeInterval(visibleRange)
                let distance = (oldTimestamp ?? latest).timeIntervalSince(
                    rightEdge
                )
                let wasLive = distance <= -(rightPadding * 0.5)

                if wasLive {
                    scrollPosition = latest.addingTimeInterval(
                        rightPadding - visibleRange
                    )
                }
            }
            .frame(height: 300)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newRange = max(
                            5.0,
                            min(300.0, baseRange / value.magnification)
                        )

                        if !isDetachedFromLive,
                            let latest = data.last?.timestamp
                        {
                            visibleRange = newRange
                            scrollPosition = latest.addingTimeInterval(
                                rightPadding - visibleRange
                            )
                        } else {
                            visibleRange = newRange
                        }
                    }
                    .onEnded { _ in
                        baseRange = visibleRange
                    }
            )
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
