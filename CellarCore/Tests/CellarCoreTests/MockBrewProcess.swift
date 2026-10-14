import Foundation
@testable import CellarCore

struct MockBrewProcess: BrewProcessProtocol {
    var stubbedOutput: ProcessOutput = ProcessOutput(stdout: "", stderr: "", exitCode: 0)
    var shouldThrow: Bool = false
    var thrownError: Error = BrewError.brewNotFound

    func run(_ arguments: [String]) async throws -> ProcessOutput {
        if shouldThrow { throw thrownError }
        return stubbedOutput
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

    var streamedArguments: [[String]] {
        lock.withLock { recorded }
    }

    var runArguments: [[String]] {
        lock.withLock { recordedRuns }
    }

    func run(_ arguments: [String]) async throws -> ProcessOutput {
        lock.withLock { recordedRuns.append(arguments) }
        return ProcessOutput(stdout: "", stderr: "", exitCode: 0)
    }

    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        lock.withLock { recorded.append(arguments) }
        return AsyncThrowingStream { $0.finish() }
    }
}
