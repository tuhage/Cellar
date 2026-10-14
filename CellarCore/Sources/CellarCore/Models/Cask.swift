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
    /// Setup notes brew prints after installing.
    public let caveats: String?
    /// Where the cask's apps are installed, such as `/Applications/Firefox.app`.
    public let appPaths: [String]
    /// Settings, caches and support files `brew uninstall --zap` deletes.
    /// May contain `~` and wildcards.
    public let zapPaths: [String]

    public var id: String { token }

    /// The token brew resolves unambiguously, including the tap if any.
    public var qualifiedToken: String {
        fullToken.isEmpty ? token : fullToken
    }

    /// The command that installs this cask, for sharing.
    public var installCommand: String { "brew install --cask \(qualifiedToken)" }

    /// The main app, if the cask installs one.
    public var appURL: URL? {
        appPaths.first.map { URL(fileURLWithPath: $0) }
    }

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
        disabled: Bool,
        caveats: String? = nil,
        appPaths: [String] = [],
        zapPaths: [String] = []
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
        self.caveats = caveats
        self.appPaths = appPaths
        self.zapPaths = zapPaths
    }

    // MARK: Actions

    /// Streams `brew install --cask` output line by line.
    public func installOutput() -> AsyncThrowingStream<String, Error> {
        BrewService.shared.install(qualifiedToken, isCask: true)
    }

    public func install() async throws {
        for try await _ in installOutput() {}
    }

    /// - Parameters:
    ///   - force: Remove it even if brew thinks it isn't installed.
    ///   - zap: Also delete the files in `zapPaths`.
    public func uninstall(force: Bool = false, zap: Bool = false) async throws {
        try await BrewService.shared.uninstall(cask: token, force: force, zap: zap)
    }

    /// Streams `brew upgrade --cask` output line by line. Uses the fully
    /// qualified token so a tap cask is never mistaken for a same-named one.
    public func upgradeOutput() -> AsyncThrowingStream<String, Error> {
        BrewService.shared.upgrade(qualifiedToken, isCask: true)
    }

    /// Upgrades even when the app updates itself, which brew otherwise
    /// leaves to the app.
    public func greedyUpgradeOutput() -> AsyncThrowingStream<String, Error> {
        BrewService.shared.upgradeGreedy(cask: qualifiedToken)
    }

    public func reinstallOutput() -> AsyncThrowingStream<String, Error> {
        BrewService.shared.reinstall(qualifiedToken, isCask: true)
    }

    public func upgrade() async throws {
        for try await _ in upgradeOutput() {}
    }

    // MARK: Factory Methods

    /// All installed casks.
    public static var all: [Cask] {
        get async throws {
            let data = try await BrewService.shared.listCasksData()
            let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
            return response.casks ?? []
        }
    }

    /// Search for casks by query. Returns stub `Cask` values with tokens only,
    /// since `brew search` returns newline-separated names (not full JSON).
    public static func search(for query: String) async throws -> [Cask] {
        let tokens = try await BrewService.shared.searchCasks(query)
        return tokens.map { Cask.stub(token: $0) }
    }

    /// Like `search(for:)`, with name, description and version for the
    /// first `detailLimit` matches; the rest stay stubs. Falls back to stubs
    /// when brew can't describe them.
    public static func search(for query: String, detailLimit: Int) async throws -> [Cask] {
        let tokens = try await BrewService.shared.searchCasks(query)
        let details = (try? await info(named: Array(tokens.prefix(detailLimit)))) ?? []
        return SearchResultOrdering.ordered(tokens, details: details, keys: { [$0.token, $0.fullToken] }, stub: stub(token:))
    }

    /// Full details of the named casks, installed or not.
    public static func info(named tokens: [String]) async throws -> [Cask] {
        guard !tokens.isEmpty else { return [] }
        let data = try await BrewService.shared.infoData(tokens, isCask: true)
        return try JSONDecoder().decode(BrewJSONResponse.self, from: data).casks ?? []
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
        case caveats
        case artifacts
        // Cellar's cache stores the paths read from `artifacts`.
        case appPaths = "app_paths"
        case zapPaths = "zap_paths"
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
        self.caveats = try container.decodeIfPresent(String.self, forKey: .caveats)

        if let appPaths = try container.decodeIfPresent([String].self, forKey: .appPaths) {
            self.appPaths = appPaths
            self.zapPaths = try container.decodeIfPresent([String].self, forKey: .zapPaths) ?? []
        } else {
            let artifacts = (try? container.decodeIfPresent([CaskArtifact].self, forKey: .artifacts)) ?? []
            self.appPaths = artifacts.compactMap(\.appPath)
            self.zapPaths = artifacts.flatMap(\.zapPaths)
        }
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
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
        try container.encodeIfPresent(caveats, forKey: .caveats)
        try container.encode(appPaths, forKey: .appPaths)
        try container.encode(zapPaths, forKey: .zapPaths)
    }
}

// MARK: - Artifacts (private decoding helpers)

/// One entry of brew's `artifacts` array — an object keyed by artifact
/// type. Only apps and the zap stanza are read; values vary by type, so
/// anything unexpected is skipped rather than failing the cask.
private struct CaskArtifact: Decodable {
    let appPath: String?
    let zapPaths: [String]

    private enum CodingKeys: String, CodingKey {
        case app, target, zap
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let appName = (try? container.decode(LenientStrings.self, forKey: .app))?.values.first {
            let target = try? container.decode(String.self, forKey: .target)
            appPath = target ?? "/Applications/\(appName)"
        } else {
            appPath = nil
        }
        let directives = (try? container.decode([ZapDirective].self, forKey: .zap)) ?? []
        zapPaths = directives.flatMap(\.paths)
    }
}

/// A `zap` directive. `rmdir` is left out: brew only removes those folders
/// when they are already empty.
private struct ZapDirective: Decodable {
    let paths: [String]

    private enum CodingKeys: String, CodingKey {
        case trash, delete
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paths = [CodingKeys.trash, .delete].flatMap { key in
            (try? container.decode(LenientStrings.self, forKey: key))?.values ?? []
        }
    }
}

/// A string, or an array whose string elements are kept and other values
/// (such as `{"target": …}` options) skipped.
private struct LenientStrings: Decodable {
    let values: [String]

    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            values = [single]
            return
        }
        var array = try decoder.unkeyedContainer()
        var strings: [String] = []
        while !array.isAtEnd {
            if let string = try? array.decode(String.self) {
                strings.append(string)
            } else {
                _ = try array.decode(Skipped.self)
            }
        }
        values = strings
    }

    private struct Skipped: Decodable {
        init(from decoder: any Decoder) throws {}
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
