//
//  ShellManager.swift
//  AeroNode
//
//  Created by Vitalii Bazavluk on 12.05.2026.
//

import Foundation

public enum ShellError: Error, LocalizedError {
    case executionFailed(status: Int, message: String)
    case unreadableOutput
    
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let status, let message):
            return "Command failed with status \(status): \(message)"
        case .unreadableOutput:
            return "Failed to read command output"
        }
    }
}

public class ShellManager {
    
    public static let shared = ShellManager()
    
    private init() {}

    public func run(_ command: String, arguments: [String] = []) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            let fullCommand = "\(command) \(arguments.joined(separator: " "))"
            process.arguments = ["-c", fullCommand]

            process.standardOutput = outputPipe
            process.standardError = errorPipe

            Task.detached {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
                    let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()

                    let output = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    let error = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: ShellError.executionFailed(status: Int(process.terminationStatus), message: error))
                    }
                } catch let runError {
                    continuation.resume(throwing: runError)
                }
            }
        }
    }
}
