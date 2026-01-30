import Foundation

// MARK: - Protocol

protocol BrewProcessProtocol: Sendable {
    func run(_ arguments: [String]) async throws -> ProcessOutput
    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error>
}

struct ProcessOutput: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

// MARK: - Implementation

nonisolated final class BrewProcess: BrewProcessProtocol, Sendable {
    private let brewPath: String

    init(brewPath: String = BrewProcess.resolveBrewPath()) {
        self.brewPath = brewPath
    }

    func run(_ arguments: [String]) async throws -> ProcessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments
        process.environment = Self.brewEnvironment()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let output = ProcessOutput(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )
                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BrewError.brewNotFound)
            }
        }
    }

    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: brewPath)
            process.arguments = arguments
            process.environment = Self.brewEnvironment()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let line = String(data: data, encoding: .utf8) {
                    continuation.yield(line)
                }
            }

            process.terminationHandler = { terminatedProcess in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil

                if terminatedProcess.terminationStatus != 0 {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.finish(throwing: BrewError.processFailure(
                        exitCode: terminatedProcess.terminationStatus,
                        stderr: stderr
                    ))
                } else {
                    continuation.finish()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: BrewError.brewNotFound)
            }

            continuation.onTermination = { @Sendable _ in
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }

    // MARK: - Private

    private static func resolveBrewPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/brew",      // Apple Silicon
            "/usr/local/bin/brew",         // Intel
            "/home/linuxbrew/.linuxbrew/bin/brew" // Linux
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? "/opt/homebrew/bin/brew"
    }

    private static func brewEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        return env
    }
}
