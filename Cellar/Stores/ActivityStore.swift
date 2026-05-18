import Foundation
import Observation

/// Tracks all in-flight and completed Homebrew operations for the current
/// session. Stores own their own Tasks; this is purely an aggregator.
@Observable
@MainActor
final class ActivityStore {

    /// Newest operations first.
    var operations: [BrewOperation] = []

    /// Maximum log lines retained per operation. Older lines are dropped.
    private static let logRingBufferSize = 200

    // MARK: Lifecycle

    /// Registers a new operation in `.running` state.
    /// Returns the new operation's id so the caller can update status / log.
    @discardableResult
    func register(kind: BrewOperation.Kind) -> UUID {
        let op = BrewOperation(kind: kind)
        operations.insert(op, at: 0)
        return op.id
    }

    /// Updates the status of an existing operation.
    func setStatus(_ id: UUID, _ status: BrewOperation.Status) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[index].status = status
        switch status {
        case .running:
            operations[index].completedAt = nil
        case .succeeded, .failed, .cancelled:
            operations[index].completedAt = Date()
        }
        if case .failed(let reason) = status {
            operations[index].error = reason
        }
    }

    /// Appends a single log line to the named operation. Caps the log at
    /// `logRingBufferSize` by dropping the oldest line.
    func appendLog(_ id: UUID, _ line: String) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[index].log.append(line)
        if operations[index].log.count > Self.logRingBufferSize {
            operations[index].log.removeFirst(operations[index].log.count - Self.logRingBufferSize)
        }
    }

    /// Marks an operation as cancelled. Callers must cancel their own Task.
    func cancel(_ id: UUID) {
        setStatus(id, .cancelled)
    }

    /// Removes every operation that is no longer running.
    func clearCompleted() {
        operations.removeAll { !$0.isRunning }
    }

    // MARK: Queries

    /// `true` if any currently-running operation targets the given name.
    /// Use this to disable per-row buttons while an op is in flight.
    func isActive(target name: String) -> Bool {
        operations.contains { op in
            op.isRunning && op.kind.targetName == name
        }
    }

    var runningCount: Int {
        operations.filter(\.isRunning).count
    }
}
