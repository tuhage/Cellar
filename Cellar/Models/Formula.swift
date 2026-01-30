import Foundation

// MARK: - Formula

struct Formula: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    let name: String
    let fullName: String
    let desc: String?
    let license: String?
    let homepage: String?
    let version: String
    let deprecated: Bool
    let disabled: Bool
    let outdated: Bool
    let pinned: Bool
    let dependencies: [String]
    let buildDependencies: [String]
    let installedOnRequest: Bool
    let installedAsDependency: Bool
    let installedVersion: String?
    let isInstalled: Bool
    let installTime: Date?
    let runtimeDependencies: [RuntimeDependency]
    let isKegOnly: Bool

    var id: String { name }

    // MARK: Actions

    func upgrade() async throws {
        let service = BrewService()
        for try await _ in service.upgrade(name) {}
    }

    func uninstall() async throws {
        let service = BrewService()
        try await service.uninstall(name)
    }

    func pin() async throws {
        let service = BrewService()
        try await service.pin(name)
    }

    func unpin() async throws {
        let service = BrewService()
        try await service.unpin(name)
    }

    // MARK: Factory Methods

    /// All installed formulae.
    static var all: [Formula] {
        get async throws {
            let service = BrewService()
            let data = try await service.listFormulaeData()
            let response = try JSONDecoder.brew.decode(BrewJSONResponse.self, from: data)
            return response.formulae
        }
    }

    /// Search for formulae by query. Returns stub `Formula` values with names only,
    /// since `brew search` returns newline-separated names (not full JSON).
    static func search(for query: String) async throws -> [Formula] {
        let service = BrewService()
        let names = try await service.searchFormulae(query)
        return names.map { Formula.stub(name: $0) }
    }

    // MARK: Preview

    static var preview: Formula {
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

struct RuntimeDependency: Codable, Hashable, Sendable {
    let fullName: String
    let version: String

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case version
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fullName = try container.decode(String.self, forKey: .fullName)
        self.version = try container.decode(String.self, forKey: .version)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(version, forKey: .version)
    }

    init(fullName: String, version: String) {
        self.fullName = fullName
        self.version = version
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

    private enum InstalledKeys: String, CodingKey {
        case version
        case installedOnRequest = "installed_on_request"
        case installedAsDependency = "installed_as_dependency"
        case time
        case runtimeDependencies = "runtime_dependencies"
    }

    nonisolated init(from decoder: any Decoder) throws {
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

        // Parse the "installed" array — may be empty or missing for search results
        let installedEntries = try container.decodeIfPresent([InstalledEntry].self, forKey: .installed)
        let firstInstalled = installedEntries?.first

        if let entry = firstInstalled {
            self.installedVersion = entry.version
            self.version = entry.version
            self.installedOnRequest = entry.installedOnRequest
            self.installedAsDependency = entry.installedAsDependency
            self.isInstalled = true
            self.runtimeDependencies = entry.runtimeDependencies ?? []
            if let timestamp = entry.time {
                self.installTime = Date(timeIntervalSince1970: TimeInterval(timestamp))
            } else {
                self.installTime = nil
            }
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

    nonisolated func encode(to encoder: any Encoder) throws {
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

    nonisolated init(
        version: String,
        installedOnRequest: Bool,
        installedAsDependency: Bool,
        time: Int?,
        runtimeDependencies: [RuntimeDependency]?
    ) {
        self.version = version
        self.installedOnRequest = installedOnRequest
        self.installedAsDependency = installedAsDependency
        self.time = time
        self.runtimeDependencies = runtimeDependencies
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(String.self, forKey: .version)
        self.installedOnRequest = try container.decodeIfPresent(Bool.self, forKey: .installedOnRequest) ?? false
        self.installedAsDependency = try container.decodeIfPresent(Bool.self, forKey: .installedAsDependency) ?? false
        self.time = try container.decodeIfPresent(Int.self, forKey: .time)
        self.runtimeDependencies = try container.decodeIfPresent([RuntimeDependency].self, forKey: .runtimeDependencies)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(installedOnRequest, forKey: .installedOnRequest)
        try container.encode(installedAsDependency, forKey: .installedAsDependency)
        try container.encodeIfPresent(time, forKey: .time)
        try container.encodeIfPresent(runtimeDependencies, forKey: .runtimeDependencies)
    }
}

// MARK: - Stub Factory

extension Formula {

    /// Creates a minimal `Formula` from just a name (used for search results).
    static func stub(name: String) -> Formula {
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

// MARK: - JSONDecoder Extension

extension JSONDecoder {
    /// A decoder configured for brew JSON output.
    nonisolated static let brew: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}
