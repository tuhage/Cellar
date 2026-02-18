import Foundation

// MARK: - Protocol

public protocol BrewProcessProtocol: Sendable {
    func run(_ arguments: [String]) async throws -> ProcessOutput
    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error>
}

public struct ProcessOutput: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

// MARK: - Implementation

public nonisolated final class BrewProcess: BrewProcessProtocol, Sendable {
    private let brewPath: String

    public init(brewPath: String = BrewProcess.resolveBrewPath()) {
        self.brewPath = brewPath
    }

    public func run(_ arguments: [String]) async throws -> ProcessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments
        process.environment = Self.brewEnvironment()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw BrewError.brewNotFound
        }

        // Read pipe data before waiting for termination to avoid deadlock.
        // If the process fills the pipe buffer (~64KB), it blocks until the
        // buffer is drained. Reading here prevents that.
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        return ProcessOutput(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    public func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            nonisolated(unsafe) let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: self.brewPath)
            process.arguments = arguments
            process.environment = Self.brewEnvironment()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Accumulate stderr concurrently to prevent deadlock.
            // If the stderr buffer fills (~64KB) without being drained,
            // the process blocks waiting for buffer space.
            nonisolated(unsafe) var stderrChunks: [Data] = []
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                stderrChunks.append(data)
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let line = String(data: data, encoding: .utf8) {
                    continuation.yield(line)
                }
            }

            process.terminationHandler = { terminatedProcess in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                if terminatedProcess.terminationStatus != 0 {
                    let stderrData = stderrChunks.reduce(Data(), +)
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

    // MARK: - Brew Path Resolution

    private static let brewCandidatePaths = [
        "/opt/homebrew/bin/brew",              // Apple Silicon
        "/usr/local/bin/brew",                 // Intel
        "/home/linuxbrew/.linuxbrew/bin/brew"  // Linux
    ]

    public static var isInstalled: Bool {
        brewCandidatePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static let _resolvedPath: String = {
        brewCandidatePaths.first { FileManager.default.fileExists(atPath: $0) }
            ?? "/opt/homebrew/bin/brew"
    }()

    public static func resolveBrewPath() -> String {
        _resolvedPath
    }

    private static func brewEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        return env
    }
}
