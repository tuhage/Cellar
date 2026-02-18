import Foundation

// MARK: - Cask

public struct Cask: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    public let token: String
    public let fullToken: String
    public let names: [String]
    public let desc: String?
    public let homepage: String?
    public let version: String
    public let installed: String?
    public let outdated: Bool
    public let autoUpdates: Bool
    public let deprecated: Bool
    public let disabled: Bool

    public var id: String { token }

    /// Whether this cask requires user attention (outdated, deprecated, or disabled).
    public var needsAttention: Bool { outdated || deprecated || disabled }

    /// The primary display name — first entry of the `name` array,
    /// falling back to the token.
    public var displayName: String {
        names.first ?? token
    }

    /// Whether this cask is currently installed.
    public var isInstalled: Bool {
        installed != nil
    }

    // MARK: Init

    public init(
        token: String,
        fullToken: String,
        names: [String],
        desc: String?,
        homepage: String?,
        version: String,
        installed: String?,
        outdated: Bool,
        autoUpdates: Bool,
        deprecated: Bool,
        disabled: Bool
    ) {
        self.token = token
        self.fullToken = fullToken
        self.names = names
        self.desc = desc
        self.homepage = homepage
        self.version = version
        self.installed = installed
        self.outdated = outdated
        self.autoUpdates = autoUpdates
        self.deprecated = deprecated
        self.disabled = disabled
    }

    // MARK: Actions

    public func install() async throws {
        let service = BrewService()
        for try await _ in service.install(token, isCask: true) {}
    }

    public func uninstall() async throws {
        let service = BrewService()
        try await service.uninstall(token)
    }

    public func upgrade() async throws {
        let service = BrewService()
        for try await _ in service.upgrade(token) {}
    }

    // MARK: Factory Methods

    /// All installed casks.
    public static var all: [Cask] {
        get async throws {
            let service = BrewService()
            let data = try await service.listCasksData()
            let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
            return response.casks ?? []
        }
    }

    /// Search for casks by query. Returns stub `Cask` values with tokens only,
    /// since `brew search` returns newline-separated names (not full JSON).
    public static func search(for query: String) async throws -> [Cask] {
        let service = BrewService()
        let tokens = try await service.searchCasks(query)
        return tokens.map { Cask.stub(token: $0) }
    }

    // MARK: Preview

    public static var preview: Cask {
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

    public nonisolated init(from decoder: any Decoder) throws {
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
}

// MARK: - Stub Factory

extension Cask {

    /// Creates a minimal `Cask` from just a token (used for search results).
    public static func stub(token: String) -> Cask {
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
