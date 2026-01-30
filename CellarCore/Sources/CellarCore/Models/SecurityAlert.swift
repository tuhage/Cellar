import Foundation

// MARK: - SecurityAlert

public struct SecurityAlert: Identifiable, Sendable {

    // MARK: Data

    public let id: UUID
    public let packageName: String
    public let alertType: SecurityAlertType
    public let severity: SecuritySeverity
    public let description: String
    public let recommendation: String

    public init(
        id: UUID = UUID(),
        packageName: String,
        alertType: SecurityAlertType,
        severity: SecuritySeverity,
        description: String,
        recommendation: String
    ) {
        self.id = id
        self.packageName = packageName
        self.alertType = alertType
        self.severity = severity
        self.description = description
        self.recommendation = recommendation
    }

    // MARK: Preview

    public static var preview: SecurityAlert {
        SecurityAlert(
            packageName: "python@3.9",
            alertType: .deprecated,
            severity: .high,
            description: "This formula has been deprecated because Python 3.9 has reached end of life.",
            recommendation: "Migrate to python@3.12 or later."
        )
    }
}

// MARK: - SecurityAlertType

public enum SecurityAlertType: String, Sendable {
    case deprecated
    case disabled
    case outdatedCritical

    public var title: String {
        switch self {
        case .deprecated: "Deprecated"
        case .disabled: "Disabled"
        case .outdatedCritical: "Critically Outdated"
        }
    }

    public var icon: String {
        switch self {
        case .deprecated: "exclamationmark.triangle.fill"
        case .disabled: "nosign"
        case .outdatedCritical: "clock.badge.exclamationmark"
        }
    }
}

// MARK: - SecuritySeverity

public enum SecuritySeverity: String, Sendable, Comparable {
    case critical
    case high
    case medium
    case low

    // MARK: Comparable

    private var sortOrder: Int {
        switch self {
        case .critical: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }

    public static func < (lhs: SecuritySeverity, rhs: SecuritySeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
