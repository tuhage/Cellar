import SwiftUI

extension BrewOperation.Status {

    /// "Finished", "Failed" — for the Activity panel, notices and log files.
    var label: String {
        switch self {
        case .running: "Running"
        case .succeeded: "Finished"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .running: .accentColor
        case .succeeded: .green
        case .failed: .red
        case .cancelled: .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .running: "clock"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "minus.circle.fill"
        }
    }
}
