import Foundation

// MARK: - MaintenanceSchedule

/// Persisted schedule settings for automatic brew maintenance tasks.
public struct MaintenanceSchedule: Codable, Sendable {

    // MARK: Settings

    public var autoCleanup: Bool = false
    public var cleanupFrequency: MaintenanceFrequency = .weekly
    public var autoHealthCheck: Bool = false
    public var healthCheckFrequency: MaintenanceFrequency = .weekly

    // MARK: Timestamps

    public var lastCleanup: Date?
    public var lastHealthCheck: Date?

    // MARK: Init

    public init(
        autoCleanup: Bool = false,
        cleanupFrequency: MaintenanceFrequency = .weekly,
        autoHealthCheck: Bool = false,
        healthCheckFrequency: MaintenanceFrequency = .weekly,
        lastCleanup: Date? = nil,
        lastHealthCheck: Date? = nil
    ) {
        self.autoCleanup = autoCleanup
        self.cleanupFrequency = cleanupFrequency
        self.autoHealthCheck = autoHealthCheck
        self.healthCheckFrequency = healthCheckFrequency
        self.lastCleanup = lastCleanup
        self.lastHealthCheck = lastHealthCheck
    }

    // Backward-compatible decoding: missing keys fall back to defaults.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autoCleanup = try container.decodeIfPresent(Bool.self, forKey: .autoCleanup) ?? false
        self.cleanupFrequency = try container.decodeIfPresent(MaintenanceFrequency.self, forKey: .cleanupFrequency) ?? .weekly
        self.autoHealthCheck = try container.decodeIfPresent(Bool.self, forKey: .autoHealthCheck) ?? false
        self.healthCheckFrequency = try container.decodeIfPresent(MaintenanceFrequency.self, forKey: .healthCheckFrequency) ?? .weekly
        self.lastCleanup = try container.decodeIfPresent(Date.self, forKey: .lastCleanup)
        self.lastHealthCheck = try container.decodeIfPresent(Date.self, forKey: .lastHealthCheck)
    }

    private enum CodingKeys: String, CodingKey {
        case autoCleanup, cleanupFrequency, autoHealthCheck, healthCheckFrequency
        case lastCleanup, lastHealthCheck
    }

    // MARK: Factory

    public static var `default`: MaintenanceSchedule { MaintenanceSchedule() }

    // MARK: Preview

    public static var preview: MaintenanceSchedule {
        MaintenanceSchedule(
            autoCleanup: true,
            cleanupFrequency: .weekly,
            autoHealthCheck: true,
            healthCheckFrequency: .monthly,
            lastCleanup: Calendar.current.date(byAdding: .day, value: -3, to: .now),
            lastHealthCheck: Calendar.current.date(byAdding: .day, value: -7, to: .now)
        )
    }

    // MARK: Schedule Logic

    /// Where a scheduled task stands. Overdue tasks run at the next hourly
    /// check while Cellar is open.
    public enum Status: Hashable, Sendable {
        case off
        /// Never run, so the next check runs it.
        case dueNow
        /// The due date has passed.
        case overdue
        case scheduled(Date)

        public var isDue: Bool {
            self == .dueNow || self == .overdue
        }
    }

    /// When a task last run at `lastRun` is due again; `nil` if it never ran.
    public static func nextRun(after lastRun: Date?, frequency: MaintenanceFrequency) -> Date? {
        lastRun.flatMap { Calendar.current.date(byAdding: frequency.calendarComponent, value: 1, to: $0) }
    }

    public static func status(
        isEnabled: Bool,
        lastRun: Date?,
        frequency: MaintenanceFrequency,
        now: Date = .now
    ) -> Status {
        guard isEnabled else { return .off }
        guard let next = nextRun(after: lastRun, frequency: frequency) else { return .dueNow }
        return next <= now ? .overdue : .scheduled(next)
    }

    public func cleanupStatus(now: Date = .now) -> Status {
        Self.status(isEnabled: autoCleanup, lastRun: lastCleanup, frequency: cleanupFrequency, now: now)
    }

    public func healthCheckStatus(now: Date = .now) -> Status {
        Self.status(isEnabled: autoHealthCheck, lastRun: lastHealthCheck, frequency: healthCheckFrequency, now: now)
    }

    public var isCleanupOverdue: Bool {
        cleanupStatus().isDue
    }

    public var isHealthCheckOverdue: Bool {
        healthCheckStatus().isDue
    }
}

// MARK: - MaintenanceFrequency

public enum MaintenanceFrequency: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly
    case monthly

    public var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    public var calendarComponent: Calendar.Component {
        switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }
}

// MARK: - MaintenanceReport

/// A record of a single maintenance run (cleanup or health check).
public struct MaintenanceReport: Identifiable, Codable, Sendable {

    // MARK: Data

    public let id: UUID
    public let date: Date
    public let type: MaintenanceReportType
    public let summary: String
    public let details: String?

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        type: MaintenanceReportType,
        summary: String,
        details: String? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.summary = summary
        self.details = details
    }

    // MARK: Preview

    public static var preview: MaintenanceReport {
        MaintenanceReport(
            date: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now,
            type: .cleanup,
            summary: "Freed 152 MB · 2 items",
            details: """
            Removing: /opt/homebrew/Cellar/node/20.0.0... (2,071 files, 88.6MB)
            Removing: /opt/homebrew/Cellar/python@3.11/3.11.5... (3,300 files, 63.4MB)
            ==> This operation has freed approximately 152MB of disk space.
            """
        )
    }
}

// MARK: - MaintenanceReportType

public enum MaintenanceReportType: String, Codable, Sendable {
    case cleanup
    case autoremove
    case healthCheck

    public var title: String {
        switch self {
        case .cleanup: "Cleanup"
        case .autoremove: "Unused Dependencies"
        case .healthCheck: "Health Check"
        }
    }

    public var icon: String {
        switch self {
        case .cleanup: "trash.circle.fill"
        case .autoremove: "shippingbox.circle.fill"
        case .healthCheck: "heart.circle.fill"
        }
    }
}
