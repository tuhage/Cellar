import Foundation

// MARK: - Protocol

public protocol BrewProcessProtocol: Sendable {
    func run(_ arguments: [String]) async throws -> ProcessOutput
    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error>

    /// Runs `brew` as root via the macOS admin authentication prompt
    /// (Touch ID / password). Used for services registered under `root`.
    func runPrivileged(_ arguments: [String]) async throws -> ProcessOutput
}

public extension BrewProcessProtocol {
    /// Default routes to the unprivileged path so test doubles need not
    /// implement privileged execution.
    func runPrivileged(_ arguments: [String]) async throws -> ProcessOutput {
        try await run(arguments)
    }
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

    public func runPrivileged(_ arguments: [String]) async throws -> ProcessOutput {
        let shellCommand = Self.privilegedShellCommand(brewPath: brewPath, arguments: arguments)
        let appleScript = "do shell script \(Self.appleScriptQuoted(shellCommand)) with administrator privileges"

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw BrewError.brewNotFound
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            // osascript reports a user-dismissed auth dialog as error -128.
            if stderr.contains("-128") || stderr.localizedCaseInsensitiveContains("User canceled") {
                throw BrewError.cancelled
            }
            throw BrewError.processFailure(exitCode: process.terminationStatus, stderr: stderr)
        }

        return ProcessOutput(stdout: stdout, stderr: stderr, exitCode: 0)
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

    // MARK: - Privileged Command Building

    /// Builds the `/bin/sh` command that `do shell script` runs as root.
    /// Each component is single-quoted so service names and paths are safe.
    private static func privilegedShellCommand(brewPath: String, arguments: [String]) -> String {
        let parts = [brewPath] + arguments
        let quoted = parts.map(shellQuoted).joined(separator: " ")
        return "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 \(quoted)"
    }

    /// Wraps a string in single quotes for `/bin/sh`, escaping embedded quotes.
    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Wraps a string as an AppleScript double-quoted literal.
    private static func appleScriptQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
