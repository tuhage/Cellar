import Foundation

// MARK: - UpgradePlan

/// What an upgrade would do, read from `brew upgrade --dry-run`: every
/// package brew would touch — including outdated dependencies and dependents
/// pulled in by the requested ones — and how much it would download.
public struct UpgradePlan: Codable, Hashable, Sendable {

    // MARK: Data

    public let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    /// Packages brew upgrades because a requested package needs them.
    public var additionalItems: [Item] {
        items.filter { !$0.isRequested }
    }

    /// Sum of the bottle sizes brew reported. Already-downloaded bottles are
    /// included, so this is an upper bound.
    public var totalDownloadBytes: Int64 {
        items.compactMap(\.downloadBytes).reduce(0, +)
    }

    // MARK: Factory Methods

    /// Asks brew what upgrading these packages would involve. Pass formula
    /// full names and cask tokens.
    public static func dryRun(formulae: [String], casks: [String]) async throws -> UpgradePlan {
        async let formulaOutput = BrewService.shared.upgradeDryRun(formulae, isCask: false)
        async let caskOutput = BrewService.shared.upgradeDryRun(casks, isCask: true)
        let items = try await parse(formulaOutput, requested: Set(formulae), isCask: false)
            + parse(caskOutput, requested: Set(casks), isCask: true)
        return UpgradePlan(items: items)
    }

    // MARK: Parsing

    /// Reads the `name old -> new (size)` lines brew prints under its
    /// "Would upgrade …" headings; everything else is ignored.
    public static func parse(_ output: String, requested: Set<String>, isCask: Bool) -> [Item] {
        var seen = Set<String>()
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { Item(line: String($0), requested: requested, isCask: isCask) }
            .filter { seen.insert($0.id).inserted }
    }

    // MARK: Preview

    public static var preview: UpgradePlan {
        UpgradePlan(items: [
            Item(name: "gradle", currentVersion: "9.7.0", targetVersion: "9.8.1",
                 downloadBytes: 157_700_000, isCask: false, isRequested: true),
            Item(name: "openjdk@17", currentVersion: "17.0.20", targetVersion: "17.0.20.1",
                 downloadBytes: 186_400_000, isCask: false, isRequested: true),
            Item(name: "gradle-completion", currentVersion: "9.6.1", targetVersion: "9.8.0",
                 downloadBytes: 17_300, isCask: false, isRequested: false),
        ])
    }
}

// MARK: - Item

extension UpgradePlan {

    public struct Item: Identifiable, Codable, Hashable, Sendable {
        /// As brew prints it; tap packages keep their `user/tap/` prefix.
        public let name: String
        public let currentVersion: String
        public let targetVersion: String
        /// Bottle size; `nil` when brew reports none (casks, source builds).
        public let downloadBytes: Int64?
        public let isCask: Bool
        /// `false` when brew pulls the package in for a requested one.
        public let isRequested: Bool

        public var id: String { "\(isCask ? "cask" : "formula"):\(name)" }

        /// The name without its tap prefix.
        public var shortName: String {
            Tap.packageName(fromQualified: name)
        }

        public init(
            name: String,
            currentVersion: String,
            targetVersion: String,
            downloadBytes: Int64?,
            isCask: Bool,
            isRequested: Bool
        ) {
            self.name = name
            self.currentVersion = currentVersion
            self.targetVersion = targetVersion
            self.downloadBytes = downloadBytes
            self.isCask = isCask
            self.isRequested = isRequested
        }

        /// Parses one `name old -> new (size)` line.
        init?(line: String, requested: Set<String>, isCask: Bool) {
            let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 4, tokens[2] == "->" else { return nil }
            let name = tokens[0]
            self.init(
                name: name,
                currentVersion: tokens[1],
                targetVersion: tokens[3],
                downloadBytes: tokens.count >= 5 ? ByteSize.parse(tokens[4]) : nil,
                isCask: isCask,
                isRequested: requested.contains(name) || requested.contains(Tap.packageName(fromQualified: name))
            )
        }
    }
}
