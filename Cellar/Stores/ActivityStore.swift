import Foundation
import Observation
import CellarCore

/// Tracks all in-flight and completed Homebrew operations for the current
/// session. Stores own their own Tasks; this is purely an aggregator.
@Observable
@MainActor
final class ActivityStore {

    /// Newest operations first.
    var operations: [BrewOperation] = []

    /// Maximum log lines retained per operation. Older lines are dropped.
    private static let logRingBufferSize = 200
    private var cancellationHandlers: [UUID: () -> Void] = [:]

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
        if case .cancelled = operations[index].status {
            // A cancelled task may unwind through a caller's generic error
            // handler. Never let that late completion rewrite the user-visible
            // cancellation as success or failure.
            return
        }
        operations[index].status = status
        switch status {
        case .running:
            operations[index].completedAt = nil
        case .succeeded, .failed, .cancelled:
            operations[index].completedAt = Date()
            cancellationHandlers[id] = nil
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
        guard let cancel = cancellationHandlers[id] else { return }
        cancel()
        setStatus(id, .cancelled)
    }

    /// Connects an activity row to the Task that owns the underlying process.
    /// Rows without a handler do not present a misleading Cancel button.
    func setCancellationHandler(_ id: UUID, _ handler: @escaping () -> Void) {
        guard operations.contains(where: { $0.id == id && $0.isRunning }) else { return }
        cancellationHandlers[id] = handler
    }

    func canCancel(_ id: UUID) -> Bool {
        cancellationHandlers[id] != nil
    }

    /// Runs an async operation in a child task and connects that task to the
    /// activity panel's Cancel button.
    func performCancellable<T: Sendable>(
        _ id: UUID?,
        operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        guard let id else { return try await operation() }
        let task = Task { @MainActor in try await operation() }
        setCancellationHandler(id) { task.cancel() }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
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

@MainActor
func withCancellableActivity<T: Sendable>(
    _ store: ActivityStore?,
    id: UUID?,
    operation: @escaping @MainActor () async throws -> T
) async throws -> T {
    if let store {
        return try await store.performCancellable(id, operation: operation)
    }
    return try await operation()
}

func isOperationCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if case BrewError.cancelled = error { return true }
    return false
}
