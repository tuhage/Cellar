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
        try await Self.execute(
            executableURL: URL(fileURLWithPath: brewPath),
            arguments: arguments,
            environment: Self.brewEnvironment()
        )
    }

    public func runPrivileged(_ arguments: [String]) async throws -> ProcessOutput {
        let shellCommand = Self.privilegedShellCommand(brewPath: brewPath, arguments: arguments)
        let appleScript = "do shell script \(Self.appleScriptQuoted(shellCommand)) with administrator privileges"

        let output = try await Self.execute(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", appleScript],
            environment: nil
        )

        guard output.exitCode == 0 else {
            // osascript reports a user-dismissed auth dialog as error -128.
            if output.stderr.contains("-128")
                || output.stderr.localizedCaseInsensitiveContains("User canceled") {
                throw BrewError.cancelled
            }
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }

        return output
    }

    public func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let worker = Task {
                do {
                    try await Self.executeStreaming(
                        executableURL: URL(fileURLWithPath: self.brewPath),
                        arguments: arguments,
                        environment: Self.brewEnvironment(),
                        continuation: continuation
                    )
                } catch is CancellationError {
                    continuation.finish(throwing: BrewError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                worker.cancel()
            }
        }
    }

    // MARK: - Process Execution

    /// Executes a process while draining stdout and stderr concurrently.
    /// Cancellation terminates the underlying process instead of only
    /// cancelling the Swift task that is waiting for it.
    private static func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let state = ProcessCancellationState(process: process)

        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            do {
                try process.run()
            } catch {
                throw BrewError.brewNotFound
            }
            state.processDidLaunch()

            async let stdoutData = readAll(from: stdoutPipe.fileHandleForReading)
            async let stderrData = readAll(from: stderrPipe.fileHandleForReading)
            async let exitCode = waitForExit(process)

            let result = await (stdoutData, stderrData, exitCode)
            try Task.checkCancellation()
            return ProcessOutput(
                stdout: String(decoding: result.0, as: UTF8.self),
                stderr: String(decoding: result.1, as: UTF8.self),
                exitCode: result.2
            )
        } onCancel: {
            state.cancel()
        }
    }

    private static func executeStreaming(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let state = ProcessCancellationState(process: process)

        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            do {
                try process.run()
            } catch {
                throw BrewError.brewNotFound
            }
            state.processDidLaunch()

            async let stdout: Void = readLines(
                from: stdoutPipe.fileHandleForReading,
                continuation: continuation
            )
            async let stderrData = readAll(from: stderrPipe.fileHandleForReading)
            async let exitCode = waitForExit(process)

            let (_, errorData, status) = await (stdout, stderrData, exitCode)
            try Task.checkCancellation()
            guard status == 0 else {
                throw BrewError.processFailure(
                    exitCode: status,
                    stderr: String(decoding: errorData, as: UTF8.self)
                )
            }
            continuation.finish()
        } onCancel: {
            state.cancel()
        }
    }

    private static func readAll(from handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: (try? handle.readToEnd()) ?? Data())
            }
        }
    }

    /// Reads complete UTF-8 lines without losing characters that happen to be
    /// split across pipe reads. A final unterminated line is also delivered.
    private static func readLines(
        from handle: FileHandle,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        await withCheckedContinuation { finished in
            DispatchQueue.global(qos: .utility).async {
                var buffer = Data()

                while true {
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else { break }
                    buffer.append(chunk)

                    while let newline = buffer.firstIndex(of: 0x0A) {
                        var lineData = buffer[..<newline]
                        if lineData.last == 0x0D { lineData = lineData.dropLast() }
                        continuation.yield(String(decoding: lineData, as: UTF8.self))
                        buffer.removeSubrange(...newline)
                    }
                }

                if !buffer.isEmpty {
                    continuation.yield(String(decoding: buffer, as: UTF8.self))
                }
                finished.resume()
            }
        }
    }

    private static func waitForExit(_ process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus)
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

/// `Process` is not Sendable. This small locked wrapper is the only value
/// shared with the cancellation handler and keeps the unsafe boundary local.
private final class ProcessCancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private var cancellationRequested = false

    init(process: Process) {
        self.process = process
    }

    func processDidLaunch() {
        lock.lock()
        let shouldTerminate = cancellationRequested
        lock.unlock()
        if shouldTerminate, process.isRunning { process.terminate() }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let isRunning = process.isRunning
        lock.unlock()
        if isRunning { process.terminate() }
    }
}
