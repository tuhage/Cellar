import SwiftUI

enum SidebarItem: String, Identifiable, CaseIterable, Sendable {
    case dashboard
    case formulae
    case casks
    case outdated
    case services
    case brewfile
    case taps
    case dependencies
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: String(localized: "Dashboard")
        case .formulae: String(localized: "Formulae")
        case .casks: String(localized: "Casks")
        case .outdated: String(localized: "Updates")
        case .services: String(localized: "Services")
        case .brewfile: String(localized: "Brewfiles")
        case .taps: String(localized: "Taps")
        case .dependencies: String(localized: "Dependencies")
        case .maintenance: String(localized: "Maintenance")
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .formulae: "terminal"
        case .casks: "macwindow"
        case .outdated: "arrow.triangle.2.circlepath"
        case .services: "gearshape.2"
        case .brewfile: "doc.text"
        case .taps: "spigot"
        case .dependencies: "point.3.connected.trianglepath.dotted"
        case .maintenance: "wrench.and.screwdriver"
        }
    }

    /// Other words people use for the page, so Quick Open finds it.
    var keywords: [String] {
        switch self {
        case .dashboard: ["overview", "home", "summary"]
        case .formulae: ["packages", "installed", "cli", "tools"]
        case .casks: ["apps", "applications"]
        case .outdated: ["outdated", "upgrade", "update"]
        case .services: ["daemons", "launchd", "resources", "cpu", "memory"]
        case .brewfile: ["bundle", "projects", "backup", "restore"]
        case .taps: ["repositories", "sources"]
        case .dependencies: ["deps", "leaves", "orphans", "unused"]
        case .maintenance: ["cleanup", "clean up", "doctor", "health", "disk", "autoremove"]
        }
    }

    func matches(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || keywords.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: .overview
        case .formulae, .casks, .outdated: .packages
        case .services: .services
        case .brewfile, .taps: .environment
        case .dependencies, .maintenance: .maintenance
        }
    }

    static func items(for section: SidebarSection) -> [SidebarItem] {
        allCases.filter { $0.section == section }
    }

    /// Resolves a stored selection or `cellar://` host, including pages that
    /// were merged into others.
    static func resolve(_ rawValue: String) -> SidebarItem? {
        if let item = SidebarItem(rawValue: rawValue) { return item }
        return switch rawValue {
        case "updates": .outdated
        case "resources": .services
        case "projects", "brewfiles": .brewfile
        default: nil
        }
    }
}

enum SidebarSection: String, Identifiable, CaseIterable, Sendable {
    case overview
    case packages
    case services
    case environment
    case maintenance

    var id: String { rawValue }

    /// `nil` for the untitled top group.
    var title: String? {
        switch self {
        case .overview: nil
        case .packages: String(localized: "Packages")
        case .services: String(localized: "Services")
        case .environment: String(localized: "Environment")
        case .maintenance: String(localized: "Maintenance")
        }
    }
}
