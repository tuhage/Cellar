import SwiftUI

enum SidebarItem: String, Identifiable, CaseIterable, Sendable {
    case dashboard
    case formulae
    case casks
    case services
    case outdated
    case search
    case brewfile
    case health
    case security
    case collections
    case dependencies
    case resources
    case history
    case projects
    case comparison
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .formulae: "Formulae"
        case .casks: "Casks"
        case .services: "Services"
        case .outdated: "Outdated"
        case .search: "Search"
        case .brewfile: "Brewfile"
        case .health: "Health"
        case .security: "Security"
        case .collections: "Collections"
        case .dependencies: "Dependencies"
        case .resources: "Resources"
        case .history: "History"
        case .projects: "Projects"
        case .comparison: "Comparison"
        case .maintenance: "Maintenance"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .formulae: "terminal"
        case .casks: "macwindow"
        case .services: "gearshape.2"
        case .outdated: "arrow.triangle.2.circlepath"
        case .search: "magnifyingglass"
        case .brewfile: "doc.text"
        case .health: "heart.text.square"
        case .security: "shield.checkered"
        case .collections: "folder"
        case .dependencies: "point.3.connected.trianglepath.dotted"
        case .resources: "gauge.with.dots.needle.67percent"
        case .history: "clock.arrow.circlepath"
        case .projects: "hammer"
        case .comparison: "arrow.left.arrow.right"
        case .maintenance: "wrench.and.screwdriver"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: .general
        case .formulae, .casks, .outdated, .search: .packages
        case .services: .services
        case .brewfile, .collections, .dependencies: .management
        case .health, .security, .resources: .monitoring
        case .history, .projects, .comparison, .maintenance: .tools
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
    case monitoring
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .packages: "Packages"
        case .services: "Services"
        case .management: "Management"
        case .monitoring: "Monitoring"
        case .tools: "Tools"
        }
    }
}
