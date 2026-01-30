import Foundation

// MARK: - HistoryEvent

/// A recorded event representing a Homebrew action (install, uninstall, upgrade, etc.).
public struct HistoryEvent: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    public let id: UUID
    public let timestamp: Date
    public let eventType: HistoryEventType
    public let packageName: String
    public let fromVersion: String?
    public let toVersion: String?
    public let details: String?

    // MARK: Init

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        eventType: HistoryEventType,
        packageName: String,
        fromVersion: String? = nil,
        toVersion: String? = nil,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.packageName = packageName
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.details = details
    }

    // MARK: Computed

    /// A human-readable summary of the event.
    public var summary: String {
        switch eventType {
        case .installed:
            if let toVersion {
                return "Installed \(packageName) \(toVersion)"
            }
            return "Installed \(packageName)"
        case .uninstalled:
            return "Uninstalled \(packageName)"
        case .upgraded:
            if let fromVersion, let toVersion {
                return "Upgraded \(packageName) from \(fromVersion) to \(toVersion)"
            }
            return "Upgraded \(packageName)"
        case .serviceStarted:
            return "Started service \(packageName)"
        case .serviceStopped:
            return "Stopped service \(packageName)"
        case .cleanup:
            return "Cleaned up \(packageName)"
        }
    }

    // MARK: Preview

    public static var preview: HistoryEvent {
        HistoryEvent(
            eventType: .installed,
            packageName: "openssl@3",
            toVersion: "3.6.0"
        )
    }

    public static var previewList: [HistoryEvent] {
        let now = Date.now
        let calendar = Calendar.current

        return [
            HistoryEvent(
                timestamp: now,
                eventType: .installed,
                packageName: "ripgrep",
                toVersion: "14.1.0"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now)!,
                eventType: .upgraded,
                packageName: "node",
                fromVersion: "21.6.0",
                toVersion: "22.0.0"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .hour, value: -5, to: now)!,
                eventType: .serviceStarted,
                packageName: "postgresql@16"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                eventType: .uninstalled,
                packageName: "wget"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                eventType: .serviceStopped,
                packageName: "redis"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .day, value: -3, to: now)!,
                eventType: .upgraded,
                packageName: "python@3.12",
                fromVersion: "3.12.3",
                toVersion: "3.12.4"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .day, value: -3, to: now)!,
                eventType: .cleanup,
                packageName: "go",
                details: "Removed 3 old versions"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .day, value: -10, to: now)!,
                eventType: .installed,
                packageName: "ffmpeg",
                toVersion: "7.0.1"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .day, value: -15, to: now)!,
                eventType: .serviceStarted,
                packageName: "nginx"
            ),
            HistoryEvent(
                timestamp: calendar.date(byAdding: .day, value: -20, to: now)!,
                eventType: .uninstalled,
                packageName: "yarn"
            ),
        ]
    }
}

// MARK: - HistoryEventType

/// The kind of action that was performed on a Homebrew package or service.
public enum HistoryEventType: String, Codable, Sendable, CaseIterable {
    case installed
    case uninstalled
    case upgraded
    case serviceStarted
    case serviceStopped
    case cleanup

    /// A display-friendly title for the event type.
    public var title: String {
        switch self {
        case .installed: "Installed"
        case .uninstalled: "Uninstalled"
        case .upgraded: "Upgraded"
        case .serviceStarted: "Service Started"
        case .serviceStopped: "Service Stopped"
        case .cleanup: "Cleanup"
        }
    }

    /// An SF Symbol name representing the event type.
    public var icon: String {
        switch self {
        case .installed: "arrow.down.circle.fill"
        case .uninstalled: "trash.circle.fill"
        case .upgraded: "arrow.up.circle.fill"
        case .serviceStarted: "play.circle.fill"
        case .serviceStopped: "stop.circle.fill"
        case .cleanup: "sparkles"
        }
    }
}
