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
    case resources
    case projects
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: String(localized: "Dashboard")
        case .formulae: String(localized: "Formulae")
        case .casks: String(localized: "Casks")
        case .services: String(localized: "Services")
        case .outdated: String(localized: "Outdated")
        case .brewfile: String(localized: "Brewfile")
        case .taps: String(localized: "Taps")
        case .dependencies: String(localized: "Dependencies")
        case .resources: String(localized: "Resources")
        case .projects: String(localized: "Projects")
        case .maintenance: String(localized: "Maintenance")
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .formulae: "terminal"
        case .casks: "macwindow"
        case .services: "gearshape.2"
        case .outdated: "arrow.triangle.2.circlepath"
        case .brewfile: "doc.text"
        case .taps: "spigot"
        case .dependencies: "point.3.connected.trianglepath.dotted"
        case .resources: "gauge.with.dots.needle.67percent"
        case .projects: "hammer"
        case .maintenance: "wrench.and.screwdriver"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: .general
        case .formulae, .casks, .outdated: .packages
        case .services: .services
        case .brewfile, .taps: .management
        case .dependencies, .resources, .projects, .maintenance: .tools
        }
    }

    static func items(for section: SidebarSection) -> [SidebarItem] {
        allCases.filter { $0.section == section }
    }
}

enum SidebarSection: String, Identifiable, CaseIterable, Sendable {
    case general
    case packages
    case services
    case management
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .packages: String(localized: "Packages")
        case .services: String(localized: "Services")
        case .management: String(localized: "Management")
        case .tools: String(localized: "Tools")
        }
    }
}
