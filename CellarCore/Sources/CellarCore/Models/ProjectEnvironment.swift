import Foundation

// MARK: - ProjectEnvironment

/// Represents a project environment with its associated Homebrew services and packages.
///
/// Each project can define which brew services should be running and which packages
/// are required. Activating a project starts its services; deactivating stops them.
public struct ProjectEnvironment: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    public let id: UUID
    public var name: String
    public var path: String
    public var services: [String]
    public var packages: [String]
    public var autoStart: Bool

    // MARK: Init

    public init(
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

    // Backward-compatible decoding: missing keys fall back to defaults.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        self.services = try container.decodeIfPresent([String].self, forKey: .services) ?? []
        self.packages = try container.decodeIfPresent([String].self, forKey: .packages) ?? []
        self.autoStart = try container.decodeIfPresent(Bool.self, forKey: .autoStart) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, services, packages, autoStart
    }

    // MARK: Preview

    public static var preview: ProjectEnvironment {
        ProjectEnvironment(
            name: "My Web App",
            path: "/Users/user/Projects/myapp",
            services: ["postgresql@16", "redis"],
            packages: ["node", "yarn", "python@3.12"],
            autoStart: true
        )
    }
}
