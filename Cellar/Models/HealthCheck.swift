import SwiftUI

// MARK: - HealthCheck

struct HealthCheck: Identifiable, Sendable {

    // MARK: Data

    let id: UUID
    let category: HealthCategory
    let severity: HealthSeverity
    let title: String
    let description: String
    let solution: String?
    let autoFixable: Bool

    init(
        id: UUID = UUID(),
        category: HealthCategory,
        severity: HealthSeverity,
        title: String,
        description: String,
        solution: String? = nil,
        autoFixable: Bool = false
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.title = title
        self.description = description
        self.solution = solution
        self.autoFixable = autoFixable
    }

    // MARK: Preview

    static var preview: HealthCheck {
        HealthCheck(
            category: .symlinks,
            severity: .warning,
            title: "Some installed kegs have no linked versions",
            description: "You may need to run `brew link` on these kegs to complete the installation.",
            solution: "Run `brew link <formula>` for each affected formula.",
            autoFixable: false
        )
    }
}

// MARK: - HealthCategory

enum HealthCategory: String, Sendable, CaseIterable {
    case symlinks
    case dependencies
    case permissions
    case conflicts
    case outdated
    case other

    var title: String {
        switch self {
        case .symlinks: "Symlinks"
        case .dependencies: "Dependencies"
        case .permissions: "Permissions"
        case .conflicts: "Conflicts"
        case .outdated: "Outdated"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .symlinks: "link"
        case .dependencies: "point.3.connected.trianglepath.dotted"
        case .permissions: "lock.shield"
        case .conflicts: "exclamationmark.triangle"
        case .outdated: "clock.arrow.2.circlepath"
        case .other: "questionmark.circle"
        }
    }
}

// MARK: - HealthSeverity

enum HealthSeverity: String, Sendable, Comparable {
    case critical
    case warning
    case info

    var color: Color {
        switch self {
        case .critical: .red
        case .warning: .yellow
        case .info: .green
        }
    }

    var icon: String {
        switch self {
        case .critical: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    // MARK: Comparable

    private var sortOrder: Int {
        switch self {
        case .critical: 0
        case .warning: 1
        case .info: 2
        }
    }

    static func < (lhs: HealthSeverity, rhs: HealthSeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
