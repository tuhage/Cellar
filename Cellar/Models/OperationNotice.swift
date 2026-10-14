import SwiftUI

/// What to tell the user about a finished operation, in a toast or a
/// system notification.
struct OperationNotice: Identifiable, Equatable {
    enum Outcome {
        case success
        case failure
        case cancelled

        var color: Color {
            switch self {
            case .success: .green
            case .failure: .red
            case .cancelled: .secondary
            }
        }

        var systemImage: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .failure: "exclamationmark.triangle.fill"
            case .cancelled: "minus.circle.fill"
            }
        }
    }

    let id: UUID
    let outcome: Outcome
    let title: String
    let message: String?

    init(operation: BrewOperation) {
        id = operation.id
        switch operation.status {
        case .succeeded, .running:
            outcome = .success
            title = operation.kind.completionTitle
            message = operation.isBatch ? "\(operation.succeededStepCount) of \(operation.steps.count) upgraded." : nil
        case .failed(let reason):
            outcome = .failure
            title = "\(operation.kind.displayTitle) failed"
            message = reason
        case .cancelled:
            outcome = .cancelled
            title = "\(operation.kind.displayTitle) cancelled"
            message = operation.isBatch
                ? "\(operation.succeededStepCount) of \(operation.steps.count) upgraded before cancelling."
                : nil
        }
    }

    /// Failures stay until dismissed so they can't be missed.
    var staysUntilDismissed: Bool { outcome == .failure }

    var spokenText: String {
        [title, message].compactMap(\.self).joined(separator: ". ")
    }
}
