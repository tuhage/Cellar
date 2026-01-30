import Foundation

// MARK: - MaintenanceSchedule

/// Persisted schedule settings for automatic brew maintenance tasks.
struct MaintenanceSchedule: Codable, Sendable {

    // MARK: Settings

    var autoCleanup: Bool = false
    var cleanupFrequency: MaintenanceFrequency = .weekly
    var autoHealthCheck: Bool = false
    var healthCheckFrequency: MaintenanceFrequency = .weekly

    // MARK: Timestamps

    var lastCleanup: Date?
    var lastHealthCheck: Date?

    // MARK: Factory

    static var `default`: MaintenanceSchedule { MaintenanceSchedule() }

    // MARK: Preview

    static var preview: MaintenanceSchedule {
        var schedule = MaintenanceSchedule()
        schedule.autoCleanup = true
        schedule.cleanupFrequency = .weekly
        schedule.autoHealthCheck = true
        schedule.healthCheckFrequency = .monthly
        schedule.lastCleanup = Calendar.current.date(byAdding: .day, value: -3, to: .now)
        schedule.lastHealthCheck = Calendar.current.date(byAdding: .day, value: -7, to: .now)
        return schedule
    }

    // MARK: Schedule Logic

    /// Returns `true` when the given task is overdue based on its frequency and last-run date.
    func isOverdue(lastRun: Date?, frequency: MaintenanceFrequency) -> Bool {
        guard let lastRun else { return true }
        let nextDue = Calendar.current.date(
            byAdding: frequency.calendarComponent,
            value: 1,
            to: lastRun
        ) ?? .distantPast
        return Date.now >= nextDue
    }

    var isCleanupOverdue: Bool {
        autoCleanup && isOverdue(lastRun: lastCleanup, frequency: cleanupFrequency)
    }

    var isHealthCheckOverdue: Bool {
        autoHealthCheck && isOverdue(lastRun: lastHealthCheck, frequency: healthCheckFrequency)
    }
}

// MARK: - MaintenanceFrequency

enum MaintenanceFrequency: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly
    case monthly

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }
}

// MARK: - MaintenanceReport

/// A record of a single maintenance run (cleanup or health check).
struct MaintenanceReport: Identifiable, Codable, Sendable {

    // MARK: Data

    let id: UUID
    let date: Date
    let type: MaintenanceReportType
    let summary: String
    let details: String?

    init(
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

    static var preview: MaintenanceReport {
        MaintenanceReport(
            date: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now,
            type: .cleanup,
            summary: "Removed 3 old versions and 150 MB of cache files.",
            details: "Removing /opt/homebrew/Cellar/node/20.0.0...\nRemoving /opt/homebrew/Cellar/python@3.11/3.11.5..."
        )
    }
}

// MARK: - MaintenanceReportType

enum MaintenanceReportType: String, Codable, Sendable {
    case cleanup
    case healthCheck

    var title: String {
        switch self {
        case .cleanup: "Cleanup"
        case .healthCheck: "Health Check"
        }
    }

    var icon: String {
        switch self {
        case .cleanup: "trash.circle.fill"
        case .healthCheck: "heart.circle.fill"
        }
    }
}
