import Foundation

// MARK: - ProjectEnvironment

/// Represents a project environment with its associated Homebrew services and packages.
///
/// Each project can define which brew services should be running and which packages
/// are required. Activating a project starts its services; deactivating stops them.
struct ProjectEnvironment: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    let id: UUID
    var name: String
    var path: String
    var services: [String]
    var packages: [String]
    var autoStart: Bool

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        services: [String] = [],
        packages: [String] = [],
        autoStart: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.services = services
        self.packages = packages
        self.autoStart = autoStart
    }

    // MARK: Preview

    static var preview: ProjectEnvironment {
        ProjectEnvironment(
            name: "My Web App",
            path: "/Users/user/Projects/myapp",
            services: ["postgresql@16", "redis"],
            packages: ["node", "yarn", "python@3.12"],
            autoStart: true
        )
    }
}
