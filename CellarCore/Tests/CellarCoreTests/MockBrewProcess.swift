import Foundation
@testable import CellarCore

struct MockBrewProcess: BrewProcessProtocol {
    var stubbedOutput: ProcessOutput = ProcessOutput(stdout: "", stderr: "", exitCode: 0)

    func run(_ arguments: [String]) async throws -> ProcessOutput {
        stubbedOutput
    }

    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

/// Records the arguments of every command.
final class RecordingBrewProcess: BrewProcessProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [[String]] = []
    private var recordedRuns: [[String]] = []
    private var recordedPrivileged: [[PrivilegedCommand]] = []

    var streamedArguments: [[String]] {
        lock.withLock { recorded }
    }

    var ranArguments: [[String]] {
        lock.withLock { recordedRuns }
    }

    /// Each element is one privileged call, i.e. one password prompt.
    var privilegedCalls: [[PrivilegedCommand]] {
        lock.withLock { recordedPrivileged }
    }

    func run(_ arguments: [String]) async throws -> ProcessOutput {
        lock.withLock { recordedRuns.append(arguments) }
        return ProcessOutput(stdout: "", stderr: "", exitCode: 0)
    }

    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        lock.withLock { recorded.append(arguments) }
        return AsyncThrowingStream { $0.finish() }
    }

    func runPrivileged(_ commands: [PrivilegedCommand]) async throws -> ProcessOutput {
        lock.withLock { recordedPrivileged.append(commands) }
        return ProcessOutput(stdout: "", stderr: "", exitCode: 0)
    }
}
