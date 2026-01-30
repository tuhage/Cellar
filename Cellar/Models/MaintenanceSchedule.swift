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

    // MARK: Init

    init(
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

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case autoCleanup, cleanupFrequency, autoHealthCheck, healthCheckFrequency
        case lastCleanup, lastHealthCheck
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autoCleanup = try container.decodeIfPresent(Bool.self, forKey: .autoCleanup) ?? false
        self.cleanupFrequency = try container.decodeIfPresent(MaintenanceFrequency.self, forKey: .cleanupFrequency) ?? .weekly
        self.autoHealthCheck = try container.decodeIfPresent(Bool.self, forKey: .autoHealthCheck) ?? false
        self.healthCheckFrequency = try container.decodeIfPresent(MaintenanceFrequency.self, forKey: .healthCheckFrequency) ?? .weekly
        self.lastCleanup = try container.decodeIfPresent(Date.self, forKey: .lastCleanup)
        self.lastHealthCheck = try container.decodeIfPresent(Date.self, forKey: .lastHealthCheck)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(autoCleanup, forKey: .autoCleanup)
        try container.encode(cleanupFrequency, forKey: .cleanupFrequency)
        try container.encode(autoHealthCheck, forKey: .autoHealthCheck)
        try container.encode(healthCheckFrequency, forKey: .healthCheckFrequency)
        try container.encodeIfPresent(lastCleanup, forKey: .lastCleanup)
        try container.encodeIfPresent(lastHealthCheck, forKey: .lastHealthCheck)
    }

    // MARK: Factory

    static var `default`: MaintenanceSchedule { MaintenanceSchedule() }

    // MARK: Preview

    static var preview: MaintenanceSchedule {
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

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = MaintenanceFrequency(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid MaintenanceFrequency: \(rawValue)"
            )
        }
        self = value
    }

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

    private enum CodingKeys: String, CodingKey {
        case id, date, type, summary, details
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.type = try container.decode(MaintenanceReportType.self, forKey: .type)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.details = try container.decodeIfPresent(String.self, forKey: .details)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(type, forKey: .type)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(details, forKey: .details)
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

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = MaintenanceReportType(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid MaintenanceReportType: \(rawValue)"
            )
        }
        self = value
    }

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
