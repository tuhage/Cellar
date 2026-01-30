import Foundation

// MARK: - Cask

struct Cask: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    let token: String
    let fullToken: String
    let names: [String]
    let desc: String?
    let homepage: String?
    let version: String
    let installed: String?
    let outdated: Bool
    let autoUpdates: Bool
    let deprecated: Bool
    let disabled: Bool

    var id: String { token }

    /// The primary display name — first entry of the `name` array,
    /// falling back to the token.
    var displayName: String {
        names.first ?? token
    }

    /// Whether this cask is currently installed.
    var isInstalled: Bool {
        installed != nil
    }

    // MARK: Actions

    func install() async throws {
        let service = BrewService()
        for try await _ in service.install(token, isCask: true) {}
    }

    func uninstall() async throws {
        let service = BrewService()
        try await service.uninstall(token)
    }

    func upgrade() async throws {
        let service = BrewService()
        for try await _ in service.upgrade(token) {}
    }

    // MARK: Factory Methods

    /// All installed casks.
    static var all: [Cask] {
        get async throws {
            let service = BrewService()
            let data = try await service.listCasksData()
            let response = try JSONDecoder.brew.decode(BrewJSONResponse.self, from: data)
            return response.casks ?? []
        }
    }

    /// Search for casks by query. Returns stub `Cask` values with tokens only,
    /// since `brew search` returns newline-separated names (not full JSON).
    static func search(for query: String) async throws -> [Cask] {
        let service = BrewService()
        let tokens = try await service.searchCasks(query)
        return tokens.map { Cask.stub(token: $0) }
    }

    // MARK: Preview

    static var preview: Cask {
        Cask(
            token: "firefox",
            fullToken: "firefox",
            names: ["Mozilla Firefox"],
            desc: "Web browser",
            homepage: "https://www.mozilla.org/firefox/",
            version: "147.0.2",
            installed: "147.0.2",
            outdated: false,
            autoUpdates: true,
            deprecated: false,
            disabled: false
        )
    }
}

// MARK: - Codable

extension Cask {

    private enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case names = "name"
        case desc
        case homepage
        case version
        case installed
        case outdated
        case autoUpdates = "auto_updates"
        case deprecated
        case disabled
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.token = try container.decode(String.self, forKey: .token)
        self.fullToken = try container.decodeIfPresent(String.self, forKey: .fullToken) ?? ""
        self.names = try container.decodeIfPresent([String].self, forKey: .names) ?? []
        self.desc = try container.decodeIfPresent(String.self, forKey: .desc)
        self.homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "unknown"
        self.installed = try container.decodeIfPresent(String.self, forKey: .installed)
        self.outdated = try container.decodeIfPresent(Bool.self, forKey: .outdated) ?? false
        self.autoUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoUpdates) ?? false
        self.deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        self.disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(token, forKey: .token)
        try container.encode(fullToken, forKey: .fullToken)
        try container.encode(names, forKey: .names)
        try container.encodeIfPresent(desc, forKey: .desc)
        try container.encodeIfPresent(homepage, forKey: .homepage)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(installed, forKey: .installed)
        try container.encode(outdated, forKey: .outdated)
        try container.encode(autoUpdates, forKey: .autoUpdates)
        try container.encode(deprecated, forKey: .deprecated)
        try container.encode(disabled, forKey: .disabled)
    }
}

// MARK: - Stub Factory

extension Cask {

    /// Creates a minimal `Cask` from just a token (used for search results).
    static func stub(token: String) -> Cask {
        Cask(
            token: token,
            fullToken: token,
            names: [],
            desc: nil,
            homepage: nil,
            version: "unknown",
            installed: nil,
            outdated: false,
            autoUpdates: false,
            deprecated: false,
            disabled: false
        )
    }
}
