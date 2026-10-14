import Foundation

/// What to tell the user about a finished operation, in a toast or a
/// system notification.
struct OperationNotice: Identifiable, Equatable {
    let id: UUID
    /// How the operation ended; see `BrewOperation.Status+UI` for its look.
    let status: BrewOperation.Status
    let title: String
    let message: String?

    init(operation: BrewOperation) {
        id = operation.id
        status = operation.status
        switch operation.status {
        case .succeeded, .running:
            title = operation.kind.completionTitle
            message = operation.isBatch ? "\(operation.succeededStepCount) of \(operation.steps.count) upgraded." : nil
        case .failed(let reason):
            title = "\(operation.kind.displayTitle) failed"
            message = reason
        case .cancelled:
            title = "\(operation.kind.displayTitle) cancelled"
            message = operation.isBatch
                ? "\(operation.succeededStepCount) of \(operation.steps.count) upgraded before cancelling."
                : nil
        }
    }

    /// Failures stay until dismissed so they can't be missed.
    var staysUntilDismissed: Bool {
        if case .failed = status { return true }
        return false
    }

    var spokenText: String {
        [title, message].compactMap(\.self).joined(separator: ". ")
    }
}
