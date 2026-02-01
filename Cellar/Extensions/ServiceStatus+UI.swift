import SwiftUI
import CellarCore

extension ServiceStatus {

    /// The display color for this service status.
    var color: Color {
        switch self {
        case .started: .green
        case .stopped: .secondary
        case .error: .red
        case .none: .secondary
        case .unknown: .orange
        }
    }

    /// A user-facing label for this service status.
    var label: String {
        switch self {
        case .started: "Running"
        case .stopped: "Stopped"
        case .error: "Error"
        case .none: "None"
        case .unknown: "Unknown"
        }
    }
}
