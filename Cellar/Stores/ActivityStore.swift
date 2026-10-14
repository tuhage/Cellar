import Foundation
import Observation
import CellarCore

/// Runs and tracks every Homebrew operation of the session.
///
/// Stores start work through `perform(_:steps:background:retry:_:)`, which
/// registers the operation, connects the Cancel button, mirrors output to the
/// log, and records how it ended — so no store repeats that bookkeeping.
@Observable
@MainActor
final class ActivityStore {

    /// Newest operations first.
    private(set) var operations: [BrewOperation] = []

    /// What Retry does for a failed operation.
    enum Retry {
        /// Run the same body again.
        case rerun
        /// Run a custom action, such as retrying only a batch's failed steps.
        case custom(@MainActor (BrewOperation) async -> Void)
        case none
    }

    /// Called once for every finished operation — announcements.
    var onFinish: ((BrewOperation) -> Void)?
    /// Called when an operation starts, moves to another step or finishes —
    /// app-wide progress such as the Dock icon. Not called per log line.
    var onChange: (() -> Void)?

    /// Maximum log lines kept in memory per operation; the file keeps all.
    private static let logRingBufferSize = 200
    private var cancellationHandlers: [UUID: () -> Void] = [:]
    private var retryHandlers: [UUID: @MainActor (BrewOperation) async -> Void] = [:]
    private let logService = ActivityLogService.shared
    /// Keeps the Mac from idle-sleeping while brew is working.
    private var sleepPrevention: (any NSObjectProtocol)?

    // MARK: Performing

    /// Runs `body` as a tracked operation and returns its value, or `nil`
    /// when it failed, was cancelled, or its target is already busy.
    ///
    /// - Parameters:
    ///   - steps: Per-package steps for batch operations.
    ///   - background: Started by Cellar rather than the user; not announced.
    ///   - retry: What the Retry button does if the operation fails.
    @discardableResult
    func perform<T: Sendable>(
        _ kind: BrewOperation.Kind,
        steps: [BrewOperation.Step] = [],
        background: Bool = false,
        retry: Retry = .rerun,
        _ body: @escaping @MainActor (ActivityContext) async throws -> T
    ) async -> T? {
        guard !isActive(kind.target) else { return nil }

        let id = register(kind, steps: steps, background: background)
        retryHandlers[id] = retryHandler(for: retry, kind: kind, steps: steps, body: body)

        let task = Task { @MainActor in
            try await body(ActivityContext(id: id, store: self))
        }
        cancellationHandlers[id] = { task.cancel() }

        do {
            let value = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            finish(id, error: nil)
            return value
        } catch {
            finish(id, error: error)
            return nil
        }
    }

    /// Runs `body` as a tracked operation, then `reload`s what it may have
    /// changed and returns whether it succeeded.
    ///
    /// Every store's action helper follows this rule: after a success the
    /// reload runs inside the operation, so its target stays busy until the
    /// lists are current; after a failure or cancellation it runs too,
    /// since brew may have changed something before it stopped.
    @discardableResult
    func perform(
        _ kind: BrewOperation.Kind,
        retry: Retry = .rerun,
        reloading reload: @escaping @MainActor () async -> Void,
        _ body: @escaping @MainActor (ActivityContext) async throws -> Void
    ) async -> Bool {
        let succeeded = await perform(kind, retry: retry) { activity in
            try await body(activity)
            await reload()
        } != nil
        if !succeeded {
            await reload()
        }
        return succeeded
    }

    /// Asks a running operation to stop. It is marked as cancelling until
    /// brew has actually exited.
    func cancel(_ id: UUID) {
        guard let index = index(of: id), let cancel = cancellationHandlers[id] else { return }
        operations[index].isCancelling = true
        cancel()
    }

    func canCancel(_ id: UUID) -> Bool {
        guard let operation = operation(id) else { return false }
        return cancellationHandlers[id] != nil && !operation.isCancelling
    }

    func canRetry(_ id: UUID) -> Bool {
        guard let operation = operation(id) else { return false }
        return operation.isFailed && retryHandlers[id] != nil && !isActive(operation.kind.target)
    }

    func retry(_ id: UUID) async {
        guard canRetry(id), let operation = operation(id), let handler = retryHandlers[id] else { return }
        await handler(operation)
    }

    // MARK: Housekeeping

    /// Removes finished operations that need no attention; failures stay
    /// until the user removes them.
    func clearCompleted() {
        operations.removeAll { !$0.isRunning && !$0.isFailed }
    }

    func remove(_ id: UUID) {
        guard operation(id)?.isRunning == false else { return }
        operations.removeAll { $0.id == id }
        retryHandlers[id] = nil
    }

    // MARK: Queries

    func operation(_ id: UUID) -> BrewOperation? {
        operations.first { $0.id == id }
    }

    /// Whether a running operation keeps `target` busy — including packages
    /// queued or upgrading inside a running batch. Use it to disable actions.
    func isActive(_ target: BrewOperation.Target) -> Bool {
        runningOperation(for: target) != nil
    }

    /// The running operation that keeps `target` busy, if any.
    func runningOperation(for target: BrewOperation.Target) -> BrewOperation? {
        operations.first { operation in
            guard operation.isRunning else { return false }
            if operation.kind.target == target { return true }
            guard case .package(let name) = target else { return false }
            return operation.steps.contains { $0.name == name && !$0.status.isFinished }
        }
    }

    /// The first running operation matching `predicate`.
    func runningOperation(where predicate: (BrewOperation) -> Bool) -> BrewOperation? {
        operations.first { $0.isRunning && predicate($0) }
    }

    var runningCount: Int {
        operations.count(where: \.isRunning)
    }

    var failedCount: Int {
        operations.count(where: \.isFailed)
    }

    /// The batch operation (such as Upgrade All) that is running, if any.
    var runningBatchOperation: BrewOperation? {
        operations.first { $0.isRunning && $0.isBatch }
    }

    /// The package's step inside a running batch operation, if any — lets a
    /// package row show "waiting", "upgrading" or "done" during Upgrade All.
    func runningBatchStep(name: String, isCask: Bool) -> BrewOperation.Step? {
        let stepID = BrewOperation.Step.id(name: name, isCask: isCask)
        return runningBatchOperation?.steps.first { $0.id == stepID }
    }

    // MARK: Context Callbacks

    fileprivate func appendLog(_ id: UUID, _ line: String) {
        guard let index = index(of: id) else { return }
        operations[index].log.append(line)
        operations[index].lastOutputAt = Date()
        logService.append(id, line)
        let overflow = operations[index].log.count - Self.logRingBufferSize
        if overflow > 0 {
            operations[index].log.removeFirst(overflow)
        }
    }

    fileprivate func setStepStatus(_ id: UUID, step stepID: String, _ status: BrewOperation.StepStatus) {
        guard let index = index(of: id),
              let stepIndex = operations[index].steps.firstIndex(where: { $0.id == stepID })
        else { return }
        operations[index].steps[stepIndex].status = status
        switch status {
        case .pending:
            break
        case .running:
            operations[index].steps[stepIndex].startedAt = Date()
        case .succeeded, .failed, .cancelled:
            operations[index].steps[stepIndex].completedAt = Date()
        }
        let step = operations[index].steps[stepIndex]
        logService.append(id, Self.logLine(for: step, position: stepIndex + 1, of: operations[index].steps.count))
        onChange?()
    }

    // MARK: Private

    private func register(_ kind: BrewOperation.Kind, steps: [BrewOperation.Step], background: Bool) -> UUID {
        var operation = BrewOperation(kind: kind, isBackground: background, steps: steps)
        operation.logFileURL = logService.begin(operation)
        for step in steps {
            logService.append(operation.id, "Queued \(step.name) \(step.currentVersion) → \(step.targetVersion)")
        }
        operations.insert(operation, at: 0)
        updateSleepPrevention()
        onChange?()
        return operation.id
    }

    /// Records the outcome. A cancelled operation ends as cancelled even when
    /// its body finished normally while unwinding.
    private func finish(_ id: UUID, error: Error?) {
        guard let index = index(of: id) else { return }
        let status: BrewOperation.Status
        if operations[index].isCancelling || error.map(isOperationCancellation) == true {
            status = .cancelled
        } else if let error {
            status = .failed(BrewOperation.Failure(error))
            logService.append(id, error.localizedDescription)
        } else {
            status = .succeeded
        }

        if status == .cancelled {
            for stepIndex in operations[index].steps.indices
            where !operations[index].steps[stepIndex].status.isFinished {
                operations[index].steps[stepIndex].status = .cancelled
            }
        }
        operations[index].status = status
        operations[index].completedAt = Date()
        operations[index].isCancelling = false
        cancellationHandlers[id] = nil
        if !operations[index].isFailed {
            retryHandlers[id] = nil
        }
        logService.end(id, status: status)
        updateSleepPrevention()
        onChange?()
        onFinish?(operations[index])
    }

    private func retryHandler<T: Sendable>(
        for retry: Retry,
        kind: BrewOperation.Kind,
        steps: [BrewOperation.Step],
        body: @escaping @MainActor (ActivityContext) async throws -> T
    ) -> (@MainActor (BrewOperation) async -> Void)? {
        switch retry {
        case .rerun:
            { [weak self] _ in await self?.perform(kind, steps: steps, body) }
        case .custom(let action):
            action
        case .none:
            nil
        }
    }

    private func index(of id: UUID) -> Int? {
        operations.firstIndex { $0.id == id }
    }

    private func updateSleepPrevention() {
        let isBusy = operations.contains(where: \.isRunning)
        if isBusy, sleepPrevention == nil {
            sleepPrevention = ProcessInfo.processInfo.beginActivity(
                options: .userInitiated,
                reason: "Running Homebrew operations"
            )
        } else if !isBusy, let sleepPrevention {
            ProcessInfo.processInfo.endActivity(sleepPrevention)
            self.sleepPrevention = nil
        }
    }

    private static func logLine(for step: BrewOperation.Step, position: Int, of total: Int) -> String {
        let prefix = "[\(position)/\(total)] \(step.name)"
        return switch step.status {
        case .pending: "\(prefix) queued"
        case .running: "\(prefix) \(step.currentVersion) → \(step.targetVersion) started"
        case .succeeded: "\(prefix) upgraded"
        case .failed(let failure): "\(prefix) failed — \(failure.reason)"
        case .cancelled: "\(prefix) not upgraded (cancelled)"
        }
    }
}

extension ActivityStore {
    /// A store holding the given operations, for previews.
    static func preview(_ operations: [BrewOperation]) -> ActivityStore {
        let store = ActivityStore()
        store.operations = operations
        return store
    }
}

// MARK: - ActivityContext

/// Handed to an operation's body so it can report output and progress.
@MainActor
struct ActivityContext {
    let id: UUID
    fileprivate let store: ActivityStore

    func log(_ line: String) {
        store.appendLog(id, line)
    }

    /// Mirrors brew's output to the log line by line and returns it.
    /// Throws when the operation was cancelled — a cancelled stream otherwise
    /// ends quietly and would look like success.
    @discardableResult
    func stream(_ output: AsyncThrowingStream<String, Error>) async throws -> [String] {
        var lines: [String] = []
        for try await line in output {
            log(line)
            lines.append(line)
        }
        try Task.checkCancellation()
        return lines
    }

    /// Logs every line of a finished command's output.
    func log(output: String) {
        for line in output.split(whereSeparator: \.isNewline) {
            log(String(line))
        }
    }

    func setStep(_ stepID: String, _ status: BrewOperation.StepStatus) {
        store.setStepStatus(id, step: stepID, status)
    }
}

// MARK: - Helpers

func isOperationCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if case BrewError.cancelled = error { return true }
    return false
}
