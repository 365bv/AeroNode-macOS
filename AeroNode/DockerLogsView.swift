//
//  DockerLogsView.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 21.05.2026.
//

import SwiftUI

/// A view that displays real-time log feeds from the running Docker containers.
struct DockerLogsView: View {
    @State private var selectedService: String = "All"
    @State private var logsText: String = "Connecting to Docker daemon..."
    @State private var envManager = EnvironmentManager()

    let services = [
        "All", "mqtt_broker", "database", "sensor_emulator", "data_collector",
        "alerter",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Logs")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                    Text("Live feed from Docker containers")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Service Filter", selection: $selectedService) {
                    ForEach(services, id: \.self) { service in
                        Text(service).tag(service)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                // Clear the logs screen for visual feedback when the service changes
                .onChange(of: selectedService) { _, newService in
                    logsText = "Fetching \(newService) logs..."
                }
            }
            .padding(.horizontal)
            .padding(.top, 30)

            ScrollView {
                Text(logsText)
                    .font(
                        .system(size: 11, weight: .regular, design: .monospaced)
                    )
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding()
        }
        // Automatically start fetching logs when the tab appears,
        // cancel when closed, and restart when the selected service changes.
        .task(id: selectedService) {
            while !Task.isCancelled {
                let fetchedLogs = await envManager.fetchLogs(
                    for: selectedService
                )

                logsText = fetchedLogs

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
