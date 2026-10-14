import Foundation

// MARK: - Protocol

public protocol BrewProcessProtocol: Sendable {
    func run(_ arguments: [String]) async throws -> ProcessOutput
    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error>

    /// Like `stream(_:)`, optionally interleaving stderr lines. When stdout
    /// isn't a terminal brew prints its progress (downloads, the update
    /// report) to stderr, so long operations want both.
    func stream(_ arguments: [String], includingStandardError: Bool) -> AsyncThrowingStream<String, Error>

    /// Runs commands as root under one macOS admin authentication prompt
    /// (Touch ID / password). Every command runs even if an earlier one
    /// failed; the result fails if any did. Used for services registered
    /// under `root`.
    func runPrivileged(_ commands: [PrivilegedCommand]) async throws -> ProcessOutput
}

/// A command for `BrewProcessProtocol.runPrivileged(_:)`.
public enum PrivilegedCommand: Sendable, Hashable {
    /// `brew` with these arguments.
    case brew([String])
    /// A system tool, such as `/bin/kill`, with its arguments.
    case tool(path: String, arguments: [String])
}

public extension BrewProcessProtocol {
    /// Runs one `brew` command as root.
    func runPrivileged(_ arguments: [String]) async throws -> ProcessOutput {
        try await runPrivileged([.brew(arguments)])
    }

    /// Default runs the `brew` commands unprivileged and skips tools, so
    /// test doubles need not implement privileged execution.
    func runPrivileged(_ commands: [PrivilegedCommand]) async throws -> ProcessOutput {
        var output = ProcessOutput(stdout: "", stderr: "", exitCode: 0)
        for case .brew(let arguments) in commands {
            output = try await run(arguments)
        }
        return output
    }

    /// Default ignores stderr so test doubles need only implement `stream(_:)`.
    func stream(_ arguments: [String], includingStandardError: Bool) -> AsyncThrowingStream<String, Error> {
        stream(arguments)
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

    public func runPrivileged(_ commands: [PrivilegedCommand]) async throws -> ProcessOutput {
        let shellCommand = Self.privilegedShellScript(commands, brewPath: brewPath)
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
        stream(arguments, includingStandardError: false)
    }

    public func stream(_ arguments: [String], includingStandardError: Bool) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let worker = Task {
                do {
                    try await Self.executeStreaming(
                        executableURL: URL(fileURLWithPath: self.brewPath),
                        arguments: arguments,
                        environment: Self.brewEnvironment(),
                        includingStandardError: includingStandardError,
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

    /// How long to keep draining a pipe after the process has exited. EOF
    /// normally arrives immediately; it only lags when a detached grandchild
    /// (a daemon started by a post-install step, say) inherited the pipe.
    private static let pipeDrainGracePeriod: Duration = .seconds(2)

    /// Executes a process while draining stdout and stderr concurrently.
    /// Cancellation terminates the underlying process instead of only
    /// cancelling the Swift task that is waiting for it.
    static func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutput {
        let process = makeProcess(executableURL: executableURL, arguments: arguments, environment: environment)
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let state = ProcessCancellationState(process: process)
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

            let stdout = PipeReader(stdoutPipe.fileHandleForReading)
            let stderr = PipeReader(stderrPipe.fileHandleForReading)
            let exitCode = await waitForExit(process)
            async let stdoutData = stdout.result(waitingAtMost: pipeDrainGracePeriod)
            async let stderrData = stderr.result(waitingAtMost: pipeDrainGracePeriod)

            let result = await (stdoutData, stderrData)
            try Task.checkCancellation()
            return ProcessOutput(
                stdout: String(decoding: result.0, as: UTF8.self),
                stderr: String(decoding: result.1, as: UTF8.self),
                exitCode: exitCode
            )
        } onCancel: {
            state.cancel()
        }
    }

    private static func executeStreaming(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        includingStandardError: Bool,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let process = makeProcess(executableURL: executableURL, arguments: arguments, environment: environment)
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let state = ProcessCancellationState(process: process)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let forwardLine: @Sendable (String) -> Void = { line in
            continuation.yield(line)
        }

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            do {
                try process.run()
            } catch {
                throw BrewError.brewNotFound
            }
            state.processDidLaunch()

            let stdout = PipeReader(stdoutPipe.fileHandleForReading, collects: false, onLine: forwardLine)
            // stderr is always collected for the failure message.
            let stderr = PipeReader(
                stderrPipe.fileHandleForReading,
                onLine: includingStandardError ? forwardLine : nil
            )
            let status = await waitForExit(process)
            async let stdoutDrained = stdout.result(waitingAtMost: pipeDrainGracePeriod)
            async let stderrData = stderr.result(waitingAtMost: pipeDrainGracePeriod)

            let (_, errorData) = await (stdoutDrained, stderrData)
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

    /// stdin is `/dev/null` so a prompt (sudo, a confirmation, a credential
    /// helper) fails fast instead of waiting forever for input that a GUI app
    /// can never provide.
    private static func makeProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?
    ) -> Process {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        return process
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

    /// Builds the `/bin/sh` script that `do shell script` runs as root: every
    /// command runs, and the script exits with the last failure's status.
    /// Each component is single-quoted so service names and paths are safe.
    static func privilegedShellScript(_ commands: [PrivilegedCommand], brewPath: String) -> String {
        let lines = commands.map { command in
            switch command {
            case .brew(let arguments):
                "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 "
                    + ([brewPath] + arguments).map(shellQuoted).joined(separator: " ")
            case .tool(let path, let arguments):
                ([path] + arguments).map(shellQuoted).joined(separator: " ")
            }
        }
        return (["s=0"] + lines.map { "\($0) || s=$?" } + ["exit $s"]).joined(separator: "; ")
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

/// Drains one end of a pipe on a background thread.
///
/// With an `onLine` handler, complete UTF-8 lines are delivered as they
/// arrive without losing characters that happen to be split across pipe
/// reads; a final unterminated line is also delivered. With `collects`,
/// every byte is also kept for `result(waitingAtMost:)`.
private final class PipeReader: @unchecked Sendable {
    private let lock = NSLock()
    private var collected = Data()
    private var isFinished = false
    private var waiter: CheckedContinuation<Data, Never>?

    init(_ handle: FileHandle, collects: Bool = true, onLine: (@Sendable (String) -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
            var buffer = Data()

            while true {
                let chunk = handle.availableData
                guard !chunk.isEmpty else { break }
                if collects { self.collect(chunk) }
                guard let onLine else { continue }
                buffer.append(chunk)

                while let newline = buffer.firstIndex(of: 0x0A) {
                    var lineData = buffer[..<newline]
                    if lineData.last == 0x0D { lineData = lineData.dropLast() }
                    onLine(String(decoding: lineData, as: UTF8.self))
                    buffer.removeSubrange(...newline)
                }
            }

            if let onLine, !buffer.isEmpty {
                onLine(String(decoding: buffer, as: UTF8.self))
            }
            self.finish()
        }
    }

    /// The collected bytes once the pipe reaches EOF. Call after the process
    /// has exited: if EOF hasn't arrived within `grace`, a grandchild is
    /// holding the pipe open and whatever was read so far is returned.
    func result(waitingAtMost grace: Duration) async -> Data {
        let deadline = Task {
            try? await Task.sleep(for: grace)
            self.finish()
        }
        defer { deadline.cancel() }

        return await withCheckedContinuation { continuation in
            lock.lock()
            if isFinished {
                let data = collected
                lock.unlock()
                continuation.resume(returning: data)
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }

    private func collect(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { return }
        collected.append(chunk)
    }

    private func finish() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let pending = waiter
        waiter = nil
        let data = collected
        lock.unlock()
        pending?.resume(returning: data)
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
