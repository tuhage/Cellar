import SwiftUI
import CellarCore

extension ServiceStatus {

    /// The display color for this service status.
    var color: Color {
        switch self {
        case .started: .green
        case .scheduled: .blue
        case .stopped, .none, .other: .secondary
        case .error: .red
        case .unknown: .orange
        }
    }

    /// A user-facing label for this service status.
    var label: String {
        switch self {
        case .started: "Running"
        case .scheduled: "Scheduled"
        case .stopped: "Stopped"
        case .none: "Not running"
        case .error: "Failed"
        case .other: "Loaded"
        case .unknown: "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .started: "play.circle.fill"
        case .scheduled: "clock"
        case .stopped, .none: "stop.circle"
        case .error: "exclamationmark.triangle.fill"
        case .other: "pause.circle"
        case .unknown: "questionmark.circle"
        }
    }

    /// One sentence on what the status means.
    var explanation: String {
        switch self {
        case .started: "Running now."
        case .scheduled: "Waiting for its next scheduled run."
        case .stopped: "Loaded in launchd; its last run exited normally."
        case .none: "Not loaded in launchd. Start it to run it now and at login."
        case .error: "Its last run exited with an error."
        case .other: "Loaded in launchd but hasn’t run yet."
        case .unknown: "launchd didn’t report a status."
        }
    }
}

extension BrewServiceItem {

    /// Status explanation plus what the exit code means, for tooltips.
    var statusHelp: String {
        guard status != .started, let exitCode, let meaning = exitCodeExplanation else {
            return "\(status.label): \(status.explanation)"
        }
        return "\(status.label): \(status.explanation) Exit code \(exitCode): \(meaning)."
    }
}
