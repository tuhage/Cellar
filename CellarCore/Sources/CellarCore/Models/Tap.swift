import Foundation

public struct Tap: Identifiable, Codable, Hashable, Sendable {

    // MARK: Properties

    public let name: String
    public let user: String
    public let repo: String
    public let path: String
    public let installed: Bool
    public let official: Bool
    public let formulaNames: [String]
    public let caskTokens: [String]
    public let formulaFiles: [String]
    public let caskFiles: [String]
    public let commandFiles: [String]
    public let remote: String
    public let customRemote: Bool
    public let isPrivate: Bool
    public let head: String
    public let lastCommit: String
    public let branch: String

    public var id: String { name }

    // MARK: Computed

    public var formulaCount: Int { formulaNames.count }

    public var caskCount: Int { caskTokens.count }

    public var totalPackages: Int { formulaCount + caskCount }

    /// How long ago the last commit was, parsed from git's relative date
    /// ("2 weeks ago"). Unknown dates count as infinitely old so they sort last.
    public var lastCommitAge: TimeInterval {
        Self.age(fromRelativeDate: lastCommit) ?? .infinity
    }

    public var githubURL: URL? {
        guard remote.contains("github.com") else { return nil }
        let cleaned = remote
            .replacingOccurrences(of: ".git", with: "")
            .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
        return URL(string: cleaned)
    }

    // MARK: Init

    public init(
        name: String,
        user: String,
        repo: String,
        path: String,
        installed: Bool,
        official: Bool,
        formulaNames: [String],
        caskTokens: [String],
        formulaFiles: [String],
        caskFiles: [String],
        commandFiles: [String],
        remote: String,
        customRemote: Bool,
        isPrivate: Bool,
        head: String,
        lastCommit: String,
        branch: String
    ) {
        self.name = name
        self.user = user
        self.repo = repo
        self.path = path
        self.installed = installed
        self.official = official
        self.formulaNames = formulaNames
        self.caskTokens = caskTokens
        self.formulaFiles = formulaFiles
        self.caskFiles = caskFiles
        self.commandFiles = commandFiles
        self.remote = remote
        self.customRemote = customRemote
        self.isPrivate = isPrivate
        self.head = head
        self.lastCommit = lastCommit
        self.branch = branch
    }

    // MARK: Actions

    /// `force` untaps even while installed packages come from the tap.
    public func remove(force: Bool = false) async throws {
        try await BrewService.shared.removeTap(name, force: force)
    }

    // MARK: Factory Methods

    public static var all: [Tap] {
        get async throws {
            let data = try await BrewService.shared.listTapsData()
            if data.isEmpty { return [] }
            return try JSONDecoder().decode([Tap].self, from: data)
        }
    }

    // MARK: Preview

    public static var preview: Tap {
        Tap(
            name: "homebrew/core",
            user: "homebrew",
            repo: "homebrew-core",
            path: "/opt/homebrew/Library/Taps/homebrew/homebrew-core",
            installed: true,
            official: true,
            formulaNames: ["wget", "curl", "git"],
            caskTokens: [],
            formulaFiles: [],
            caskFiles: [],
            commandFiles: [],
            remote: "https://github.com/Homebrew/homebrew-core",
            customRemote: false,
            isPrivate: false,
            head: "abc1234",
            lastCommit: "2 hours ago",
            branch: "main"
        )
    }
}

// MARK: - Packages

extension Tap {

    /// The tap a package comes from, given its fully qualified name
    /// (`user/repo/name`). Core formulae and casks have unqualified names.
    public static func tapName(ofPackage qualifiedName: String, isCask: Bool) -> String {
        let parts = qualifiedName.split(separator: "/")
        guard parts.count == 3 else { return isCask ? "homebrew/cask" : "homebrew/core" }
        return "\(parts[0])/\(parts[1])".lowercased()
    }

    /// The package name without its `user/repo/` prefix.
    public static func packageName(fromQualified qualifiedName: String) -> String {
        qualifiedName.split(separator: "/").last.map(String.init) ?? qualifiedName
    }
}

// MARK: - Relative Dates

extension Tap {

    private static let unitSeconds: [String: TimeInterval] = [
        "second": 1, "minute": 60, "hour": 3_600, "day": 86_400,
        "week": 604_800, "month": 2_592_000, "year": 31_536_000,
    ]

    /// Sums every "N unit" pair, so "1 year, 2 months ago" works too.
    static func age(fromRelativeDate text: String) -> TimeInterval? {
        let words = text.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .map(String.init)
        var total: TimeInterval?
        for (count, unit) in zip(words, words.dropFirst()) {
            guard let value = Double(count) else { continue }
            let singular = unit.hasSuffix("s") ? String(unit.dropLast()) : unit
            guard let seconds = unitSeconds[singular] else { continue }
            total = (total ?? 0) + value * seconds
        }
        return total
    }
}

// MARK: - Codable

extension Tap {

    private enum CodingKeys: String, CodingKey {
        case name
        case user
        case repo
        case path
        case installed
        case official
        case formulaNames = "formula_names"
        case caskTokens = "cask_tokens"
        case formulaFiles = "formula_files"
        case caskFiles = "cask_files"
        case commandFiles = "command_files"
        case remote
        case customRemote = "custom_remote"
        case isPrivate = "private"
        case head = "HEAD"
        case lastCommit = "last_commit"
        case branch
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.user = try container.decodeIfPresent(String.self, forKey: .user) ?? ""
        self.repo = try container.decodeIfPresent(String.self, forKey: .repo) ?? ""
        self.path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        self.installed = try container.decodeIfPresent(Bool.self, forKey: .installed) ?? false
        self.official = try container.decodeIfPresent(Bool.self, forKey: .official) ?? false
        self.formulaNames = try container.decodeIfPresent([String].self, forKey: .formulaNames) ?? []
        self.caskTokens = try container.decodeIfPresent([String].self, forKey: .caskTokens) ?? []
        self.formulaFiles = try container.decodeIfPresent([String].self, forKey: .formulaFiles) ?? []
        self.caskFiles = try container.decodeIfPresent([String].self, forKey: .caskFiles) ?? []
        self.commandFiles = try container.decodeIfPresent([String].self, forKey: .commandFiles) ?? []
        self.remote = try container.decodeIfPresent(String.self, forKey: .remote) ?? ""
        self.customRemote = try container.decodeIfPresent(Bool.self, forKey: .customRemote) ?? false
        self.isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        self.head = try container.decodeIfPresent(String.self, forKey: .head) ?? ""
        self.lastCommit = try container.decodeIfPresent(String.self, forKey: .lastCommit) ?? ""
        self.branch = try container.decodeIfPresent(String.self, forKey: .branch) ?? ""
    }
}
