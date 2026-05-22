//
//  MQTTManager.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 21.05.2026.
//

import CocoaMQTT
import Combine
import Foundation
import UserNotifications

/// Structure for decoding JSON telemetry payloads received from the Python backend.
struct TurbinePayload: Codable {
    let turbine_id: String
    let wind_speed_ms: Double
    let rotor_speed_rpm: Double
    let power_output_kw: Double
    let gearbox_temp_c: Double
    let timestamp_ns: Int64
    let is_anomaly: Bool
}

/// Structure for decoding JSON alert payloads received from the Python backend.
struct AlertPayload: Codable {
    let turbine_id: String
    let message: String
    let timestamp: Int64
}

private let jsonDecoder = JSONDecoder()

/// Manages MQTT connections, subscriptions, and data ingestion from the local broker.
class MQTTManager: CocoaMQTTDelegate {
    var mqtt: CocoaMQTT?

    /// A Combine subject that broadcasts incoming telemetry points to subscribers.
    let telemetrySubject = PassthroughSubject<TelemetryPoint, Never>()

    /// Initializes and starts the MQTT client connection to the local broker.
    func start() {
        let clientID = "AeroNode-Mac-\(UUID().uuidString.prefix(5))"

        // Connect to localhost since Docker maps the port to the Mac
        mqtt = CocoaMQTT(clientID: clientID, host: "127.0.0.1", port: 1883)
        mqtt?.keepAlive = 60
        mqtt?.delegate = self
        _ = mqtt?.connect()
    }

    // --- Delegate Methods ---
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            print("✅ Swift MQTT Connected to Broker!")
            mqtt.subscribe(
                "norway/energy/wind-turbine/+/status",
                qos: CocoaMQTTQoS.qos0
            )
            mqtt.subscribe("norway/energy/alerts", qos: CocoaMQTTQoS.qos1)
        }
    }

    /// Handles incoming messages from the MQTT broker, parsing telemetry or triggering alerts.
    func mqtt(
        _ mqtt: CocoaMQTT,
        didReceiveMessage message: CocoaMQTTMessage,
        id: UInt16
    ) {
        guard let payloadString = message.string,
            let jsonData = payloadString.data(using: .utf8)
        else { return }

        if message.topic.contains("/status") {
            do {
                let payload = try jsonDecoder.decode(
                    TurbinePayload.self,
                    from: jsonData
                )
                let currentNs = Int64(
                    Date().timeIntervalSince1970 * 1_000_000_000
                )
                let latencyNs = currentNs - payload.timestamp_ns
                let latencyMs = Double(latencyNs) / 1_000_000.0

                let point = TelemetryPoint(
                    turbineId: payload.turbine_id,
                    timestamp: Date(),
                    powerOutput: payload.power_output_kw,
                    gearboxTemp: payload.gearbox_temp_c,
                    rotorSpeed: payload.rotor_speed_rpm,
                    windSpeed: payload.wind_speed_ms,
                    latency: max(0.1, latencyMs)
                )
                telemetrySubject.send(point)
            } catch {
                print("❌ JSON Decode Error: \(error)")
            }
        } else if message.topic == "norway/energy/alerts" {
            do {
                let alert = try jsonDecoder.decode(
                    AlertPayload.self,
                    from: jsonData
                )
                triggerMacNotification(
                    title: "🚨 AeroNode Alert: \(alert.turbine_id)",
                    body: alert.message
                )
            } catch {
                print("❌ Alert Decode Error: \(error)")
            }
        }
    }

    private func triggerMacNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        // Use a unique ID so notifications do not immediately replace each other
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show notification: \(error)")
            }
        }
    }

    func sendControlCommand(count: Int, qos: Int) {
        let payload = "{\"count\": \(count), \"qos\": \(qos)}"
        mqtt?.publish(
            "sim/control/turbine_count",
            withString: payload,
            qos: .qos1
        )
    }
    // --- Required Delegate Stubs ---
    func mqtt(
        _ mqtt: CocoaMQTT,
        didPublishMessage message: CocoaMQTTMessage,
        id: UInt16
    ) {}

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}

    func mqtt(
        _ mqtt: CocoaMQTT,
        didSubscribeTopics success: NSDictionary,
        failed: [String]
    ) {}

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}

    func mqttDidPing(_ mqtt: CocoaMQTT) {}

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        print("⚠️ Swift MQTT Disconnected: \(String(describing: err))")
    }
}
