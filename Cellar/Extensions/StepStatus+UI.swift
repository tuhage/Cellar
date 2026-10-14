import SwiftUI

extension BrewOperation.StepStatus {

    /// The display color for this step status.
    var color: Color {
        switch self {
        case .pending: .secondary
        case .running: .accentColor
        case .succeeded: .green
        case .failed: .red
        case .cancelled: .secondary
        }
    }

    /// A user-facing label for this step status.
    var label: String {
        switch self {
        case .pending: "Waiting"
        case .running: "Upgrading"
        case .succeeded: "Upgraded"
        case .failed: "Failed"
        case .cancelled: "Not upgraded"
        }
    }

    /// SF Symbol for this step status. Running steps show a spinner instead.
    var symbolName: String {
        switch self {
        case .pending: "clock"
        case .running: "arrow.up.circle"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .cancelled: "minus.circle"
        }
    }
}
