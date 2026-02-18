import Foundation

// MARK: - Formula

public struct Formula: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    public let name: String
    public let fullName: String
    public let desc: String?
    public let license: String?
    public let homepage: String?
    public let version: String
    public let deprecated: Bool
    public let disabled: Bool
    public let outdated: Bool
    public let pinned: Bool
    public let dependencies: [String]
    public let buildDependencies: [String]
    public let installedOnRequest: Bool
    public let installedAsDependency: Bool
    public let installedVersion: String?
    public let isInstalled: Bool
    public let installTime: Date?
    public let runtimeDependencies: [RuntimeDependency]
    public let isKegOnly: Bool

    public var id: String { name }

    /// Whether this formula requires user attention (outdated, deprecated, or disabled).
    public var needsAttention: Bool { outdated || deprecated || disabled }

    // MARK: Init

    public init(
        name: String,
        fullName: String,
        desc: String?,
        license: String?,
        homepage: String?,
        version: String,
        deprecated: Bool,
        disabled: Bool,
        outdated: Bool,
        pinned: Bool,
        dependencies: [String],
        buildDependencies: [String],
        installedOnRequest: Bool,
        installedAsDependency: Bool,
        installedVersion: String?,
        isInstalled: Bool,
        installTime: Date?,
        runtimeDependencies: [RuntimeDependency],
        isKegOnly: Bool
    ) {
        self.name = name
        self.fullName = fullName
        self.desc = desc
        self.license = license
        self.homepage = homepage
        self.version = version
        self.deprecated = deprecated
        self.disabled = disabled
        self.outdated = outdated
        self.pinned = pinned
        self.dependencies = dependencies
        self.buildDependencies = buildDependencies
        self.installedOnRequest = installedOnRequest
        self.installedAsDependency = installedAsDependency
        self.installedVersion = installedVersion
        self.isInstalled = isInstalled
        self.installTime = installTime
        self.runtimeDependencies = runtimeDependencies
        self.isKegOnly = isKegOnly
    }

    // MARK: Actions

    public static func install(name: String) async throws {
        let service = BrewService()
        for try await _ in service.install(name, isCask: false) {}
    }

    public func upgrade() async throws {
        let service = BrewService()
        for try await _ in service.upgrade(name) {}
    }

    public func uninstall() async throws {
        let service = BrewService()
        try await service.uninstall(name)
    }

    public func pin() async throws {
        let service = BrewService()
        try await service.pin(name)
    }

    public func unpin() async throws {
        let service = BrewService()
        try await service.unpin(name)
    }

    // MARK: Factory Methods

    /// All installed formulae.
    public static var all: [Formula] {
        get async throws {
            let service = BrewService()
            let data = try await service.listFormulaeData()
            let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
            return response.formulae
        }
    }

    /// Search for formulae by query. Returns stub `Formula` values with names only,
    /// since `brew search` returns newline-separated names (not full JSON).
    public static func search(for query: String) async throws -> [Formula] {
        let service = BrewService()
        let names = try await service.searchFormulae(query)
        return names.map { Formula.stub(name: $0) }
    }

    // MARK: Preview

    public static var preview: Formula {
        Formula(
            name: "openssl@3",
            fullName: "openssl@3",
            desc: "Cryptography and SSL/TLS Toolkit",
            license: "Apache-2.0",
            homepage: "https://openssl.org/",
            version: "3.6.0",
            deprecated: false,
            disabled: false,
            outdated: true,
            pinned: false,
            dependencies: ["ca-certificates"],
            buildDependencies: [],
            installedOnRequest: false,
            installedAsDependency: true,
            installedVersion: "3.6.0",
            isInstalled: true,
            installTime: Date(timeIntervalSince1970: 1_768_746_915),
            runtimeDependencies: [
                RuntimeDependency(fullName: "ca-certificates", version: "2025-12-02")
            ],
            isKegOnly: false
        )
    }
}

// MARK: - RuntimeDependency

public struct RuntimeDependency: Codable, Hashable, Sendable {
    public let fullName: String
    public let version: String

    public init(fullName: String, version: String) {
        self.fullName = fullName
        self.version = version
    }

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case version
    }
}

// MARK: - Codable

extension Formula {

    private enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case desc
        case license
        case homepage
        case versions
        case deprecated
        case disabled
        case outdated
        case pinned
        case dependencies
        case buildDependencies = "build_dependencies"
        case installed
        case isKegOnly = "keg_only"
    }

    private enum VersionsKeys: String, CodingKey {
        case stable
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.fullName = try container.decode(String.self, forKey: .fullName)
        self.desc = try container.decodeIfPresent(String.self, forKey: .desc)
        self.license = try container.decodeIfPresent(String.self, forKey: .license)
        self.homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        self.deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        self.disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
        self.outdated = try container.decodeIfPresent(Bool.self, forKey: .outdated) ?? false
        self.pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        self.dependencies = try container.decodeIfPresent([String].self, forKey: .dependencies) ?? []
        self.buildDependencies = try container.decodeIfPresent([String].self, forKey: .buildDependencies) ?? []
        self.isKegOnly = try container.decodeIfPresent(Bool.self, forKey: .isKegOnly) ?? false

        // Parse the "versions" object for the stable version
        let stableVersion: String?
        if let versionsContainer = try? container.nestedContainer(keyedBy: VersionsKeys.self, forKey: .versions) {
            stableVersion = try versionsContainer.decodeIfPresent(String.self, forKey: .stable)
        } else {
            stableVersion = nil
        }

        // Parse the "installed" array -- may be empty or missing for search results
        if let entry = try container.decodeIfPresent([InstalledEntry].self, forKey: .installed)?.first {
            self.installedVersion = entry.version
            self.version = entry.version
            self.installedOnRequest = entry.installedOnRequest
            self.installedAsDependency = entry.installedAsDependency
            self.isInstalled = true
            self.runtimeDependencies = entry.runtimeDependencies ?? []
            self.installTime = entry.time.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        } else {
            self.installedVersion = nil
            self.version = stableVersion ?? "unknown"
            self.installedOnRequest = false
            self.installedAsDependency = false
            self.isInstalled = false
            self.runtimeDependencies = []
            self.installTime = nil
        }
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(fullName, forKey: .fullName)
        try container.encodeIfPresent(desc, forKey: .desc)
        try container.encodeIfPresent(license, forKey: .license)
        try container.encodeIfPresent(homepage, forKey: .homepage)
        try container.encode(deprecated, forKey: .deprecated)
        try container.encode(disabled, forKey: .disabled)
        try container.encode(outdated, forKey: .outdated)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(dependencies, forKey: .dependencies)
        try container.encode(buildDependencies, forKey: .buildDependencies)
        try container.encode(isKegOnly, forKey: .isKegOnly)

        // Encode versions
        var versionsContainer = container.nestedContainer(keyedBy: VersionsKeys.self, forKey: .versions)
        try versionsContainer.encode(version, forKey: .stable)

        // Encode installed array
        if isInstalled {
            let entry = InstalledEntry(
                version: installedVersion ?? version,
                installedOnRequest: installedOnRequest,
                installedAsDependency: installedAsDependency,
                time: installTime.map { Int($0.timeIntervalSince1970) },
                runtimeDependencies: runtimeDependencies.isEmpty ? nil : runtimeDependencies
            )
            try container.encode([entry], forKey: .installed)
        } else {
            try container.encode([InstalledEntry](), forKey: .installed)
        }
    }
}

// MARK: - InstalledEntry (private decoding helper)

/// Represents a single entry in the `installed` array of the brew formula JSON.
private struct InstalledEntry: Codable, Sendable {
    let version: String
    let installedOnRequest: Bool
    let installedAsDependency: Bool
    let time: Int?
    let runtimeDependencies: [RuntimeDependency]?

    private enum CodingKeys: String, CodingKey {
        case version
        case installedOnRequest = "installed_on_request"
        case installedAsDependency = "installed_as_dependency"
        case time
        case runtimeDependencies = "runtime_dependencies"
    }

    // Custom decoding: missing boolean keys default to false.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(String.self, forKey: .version)
        self.installedOnRequest = try container.decodeIfPresent(Bool.self, forKey: .installedOnRequest) ?? false
        self.installedAsDependency = try container.decodeIfPresent(Bool.self, forKey: .installedAsDependency) ?? false
        self.time = try container.decodeIfPresent(Int.self, forKey: .time)
        self.runtimeDependencies = try container.decodeIfPresent([RuntimeDependency].self, forKey: .runtimeDependencies)
    }

    // Used by Formula.encode(to:) to construct entries for encoding.
    init(version: String, installedOnRequest: Bool, installedAsDependency: Bool, time: Int?, runtimeDependencies: [RuntimeDependency]?) {
        self.version = version
        self.installedOnRequest = installedOnRequest
        self.installedAsDependency = installedAsDependency
        self.time = time
        self.runtimeDependencies = runtimeDependencies
    }
}

// MARK: - Stub Factory

extension Formula {

    /// Creates a minimal `Formula` from just a name (used for search results).
    public static func stub(name: String) -> Formula {
        Formula(
            name: name,
            fullName: name,
            desc: nil,
            license: nil,
            homepage: nil,
            version: "unknown",
            deprecated: false,
            disabled: false,
            outdated: false,
            pinned: false,
            dependencies: [],
            buildDependencies: [],
            installedOnRequest: false,
            installedAsDependency: false,
            installedVersion: nil,
            isInstalled: false,
            installTime: nil,
            runtimeDependencies: [],
            isKegOnly: false
        )
    }
}
