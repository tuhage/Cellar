import Foundation

// MARK: - BrewfileLibrary

/// Everything the Brewfiles page saves: the list and the active project.
public struct BrewfileLibrary: Codable, Equatable, Sendable {
    public var brewfiles: [Brewfile]
    public var activation: ProjectActivation?

    public init(brewfiles: [Brewfile] = [], activation: ProjectActivation? = nil) {
        self.brewfiles = brewfiles
        self.activation = activation
    }

    public static let fileName = "brewfiles.json"

    /// The saved library; on first launch — or if the saved one can't be
    /// read — the one migrated from the Brewfile profiles and projects of
    /// earlier versions. Their files are left in place, so nothing is lost
    /// if migration missed something.
    public static func load(using persistence: PersistenceService = PersistenceService()) -> BrewfileLibrary {
        if let saved = try? persistence.load(BrewfileLibrary.self, from: fileName) {
            return saved
        }
        return migrated(
            profiles: persistence.loadOrDefault([LegacyProfile].self, from: LegacyProfile.fileName, default: []),
            projects: persistence.loadOrDefault([LegacyProject].self, from: LegacyProject.fileName, default: []),
            activeProjectID: persistence.loadOrDefault(UUID?.self, from: LegacyProject.activeIDFileName, default: nil)
        )
    }

    // MARK: Migration

    /// A Brewfile profile saved by Cellar 1.6 and earlier.
    public struct LegacyProfile: Decodable, Sendable {
        static let fileName = "brewfile_profiles.json"
        public let id: UUID
        public let name: String
        public let path: String
        public let lastExported: Date?

        public init(id: UUID, name: String, path: String, lastExported: Date?) {
            self.id = id
            self.name = name
            self.path = path
            self.lastExported = lastExported
        }
    }

    /// A project environment saved by Cellar 1.6 and earlier.
    public struct LegacyProject: Decodable, Sendable {
        static let fileName = "project_environments.json"
        static let activeIDFileName = "active_project_id.json"
        public let id: UUID
        public let name: String
        public let path: String
        public let services: [String]?
        public let packages: [String]?

        public init(id: UUID, name: String, path: String, services: [String]?, packages: [String]?) {
            self.id = id
            self.name = name
            self.path = path
            self.services = services
            self.packages = packages
        }
    }

    /// Profiles become `.mac` Brewfiles — the one at `~/Brewfile` is "This
    /// Mac". Projects become `.project` Brewfiles in their folder; their
    /// packages are queued to be written into that Brewfile. The active
    /// project stays active, owning all its services as before.
    public static func migrated(
        profiles: [LegacyProfile],
        projects: [LegacyProject],
        activeProjectID: UUID?
    ) -> BrewfileLibrary {
        let macBrewfiles = profiles.map { profile in
            Brewfile(
                id: profile.id,
                kind: .mac,
                name: Brewfile.isDefaultMacPath(profile.path) ? "This Mac" : profile.name,
                path: profile.path,
                lastExported: profile.lastExported
            )
        }
        let projectBrewfiles = projects.map { project in
            let isBrewfilePath = (project.path as NSString).lastPathComponent == "Brewfile"
            return Brewfile(
                id: project.id,
                kind: .project,
                name: project.name,
                path: isBrewfilePath ? project.path : (project.path as NSString).appendingPathComponent("Brewfile"),
                services: project.services ?? [],
                pendingPackages: project.packages ?? []
            )
        }
        let activation = projects.first { $0.id == activeProjectID }.map {
            ProjectActivation(brewfileID: $0.id, startedServices: $0.services ?? [])
        }
        return BrewfileLibrary(brewfiles: macBrewfiles + projectBrewfiles, activation: activation)
    }
}
