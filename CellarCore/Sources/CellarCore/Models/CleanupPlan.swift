import Foundation

// MARK: - CleanupDepth

/// How thoroughly `brew cleanup` clears the download cache.
public enum CleanupDepth: String, Codable, Hashable, Sendable, CaseIterable {
    /// Old versions, downloads older than brew's age limit, logs.
    case standard
    /// Also every cached download, even for current versions
    /// (`--prune=all --scrub`); reinstalling downloads them again.
    case deep

    var arguments: [String] {
        switch self {
        case .standard: []
        case .deep: ["--prune=all", "-s"]
        }
    }
}

// MARK: - CleanupPlan

/// What `brew cleanup` or `brew autoremove` would remove — or did remove —
/// read from their output. The same parser reads a dry run and a real run,
/// so a preview and the report after it describe things the same way.
public struct CleanupPlan: Hashable, Sendable {

    // MARK: Data

    public let items: [Item]
    /// brew's own total ("would free approximately 2.3GB"), which is more
    /// accurate than adding up items; `nil` when brew printed none.
    public let reclaimableBytes: Int64?

    public init(items: [Item], reclaimableBytes: Int64?) {
        self.items = items
        self.reclaimableBytes = reclaimableBytes
    }

    public var isEmpty: Bool { items.isEmpty }

    /// Non-empty groups in `Category` order.
    public var groups: [Group] {
        Category.allCases.compactMap { category in
            let items = items.filter { $0.category == category }
            return items.isEmpty ? nil : Group(category: category, items: items)
        }
    }

    /// One line for a report: "Freed 1.2 GB · 14 items".
    public var resultSummary: String {
        guard !isEmpty || reclaimableBytes != nil else {
            return "Nothing to clean up. Homebrew is tidy."
        }
        var parts: [String] = []
        if let reclaimableBytes {
            parts.append("Freed \(reclaimableBytes.formatted(.byteCount(style: .file)))")
        }
        if !isEmpty {
            parts.append("\(items.count) \(items.count == 1 ? "item" : "items")")
        }
        return parts.joined(separator: " · ")
    }

    /// One line for an autoremove report: "Removed libnghttp3 and libngtcp2."
    public var autoremoveSummary: String {
        let names = items.filter { $0.category == .unusedDependencies }.map(\.title)
        return names.isEmpty
            ? "No unused dependencies to remove."
            : "Removed \(names.formatted(.list(type: .and)))."
    }

    // MARK: Factory Methods

    /// Asks brew what a cleanup would remove, without removing anything.
    public static func cleanupDryRun(_ depth: CleanupDepth = .standard) async throws -> CleanupPlan {
        async let output = BrewService.shared.cleanupDryRun(depth)
        async let cachePath = BrewService.shared.path(of: .cache)
        return try await parse(output, cachePath: cachePath)
    }

    /// Asks brew which unused dependencies `brew autoremove` would uninstall.
    public static func autoremoveDryRun() async throws -> CleanupPlan {
        try await parse(BrewService.shared.autoremoveDryRun())
    }

    // MARK: Parsing

    /// Reads `Would remove:`/`Removing:` and `Would prune`/`Pruning` lines,
    /// the formula list under `Would autoremove`/`Autoremoving`, and the
    /// "approximately X of disk space" total. Anything else — warnings,
    /// "Uninstalling …" lines — is ignored.
    ///
    /// - Parameter cachePath: `brew --cache`, so a custom `HOMEBREW_CACHE`
    ///   is still grouped as downloads.
    public static func parse(_ output: String, cachePath: String? = nil) -> CleanupPlan {
        var items: [Item] = []
        var reclaimableBytes: Int64?
        var isReadingAutoremoveList = false

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if isReadingAutoremoveList, !line.isEmpty, !line.contains(" ") {
                items.append(Item(title: line, path: nil, bytes: nil, category: .unusedDependencies))
                continue
            }
            isReadingAutoremoveList = false

            if line.contains("Would autoremove") || line.contains("Autoremoving") {
                isReadingAutoremoveList = true
            } else if let bytes = freedBytes(in: line) {
                reclaimableBytes = bytes
            } else if let item = Item(line: line, cachePath: cachePath) {
                items.append(item)
            }
        }
        return CleanupPlan(items: items, reclaimableBytes: reclaimableBytes)
    }

    /// The size in "This operation would free / has freed approximately
    /// 2.3GB of disk space."
    static func freedBytes(in line: String) -> Int64? {
        guard let start = line.range(of: "approximately "),
              let end = line.range(of: " of disk space", range: start.upperBound..<line.endIndex)
        else { return nil }
        return UpgradePlan.parseSize(String(line[start.upperBound..<end.lowerBound]))
    }

    // MARK: Preview

    public static var preview: CleanupPlan {
        parse("""
        Would remove: /opt/homebrew/Cellar/node/26.5.0 (2,071 files, 88.6MB)
        Would remove: /opt/homebrew/Cellar/openjdk/26.0.1 (549 files, 398MB)
        ==> Would autoremove 1 unneeded formula:
        libngtcp2
        Would remove: /Users/me/Library/Caches/Homebrew/portable-ruby-4.0.7.arm64_big_sur.bottle.tar.gz (12.7MB)
        Would remove: /Users/me/Library/Logs/Homebrew/node (3 files, 12KB)
        Would remove (empty directory): /opt/homebrew/lib/gio
        ==> This operation would free approximately 499.3MB of disk space.
        """, cachePath: "/Users/me/Library/Caches/Homebrew")
    }
}

// MARK: - Category

extension CleanupPlan {

    public enum Category: String, CaseIterable, Hashable, Sendable {
        case oldVersions
        case unusedDependencies
        case downloads
        case logs
        case other

        public var title: String {
            switch self {
            case .oldVersions: "Old Versions"
            case .unusedDependencies: "Unused Dependencies"
            case .downloads: "Downloads and Caches"
            case .logs: "Logs"
            case .other: "Other Files"
            }
        }

        public var systemImage: String {
            switch self {
            case .oldVersions: "clock.arrow.circlepath"
            case .unusedDependencies: "shippingbox"
            case .downloads: "arrow.down.circle"
            case .logs: "doc.text"
            case .other: "folder"
            }
        }

        /// Where brew keeps what the path points to.
        static func of(path: String, cachePath: String?) -> Category {
            if let cachePath, path.hasPrefix(cachePath + "/") || path == cachePath { return .downloads }
            if path.contains("/Caches/Homebrew") { return .downloads }
            if path.contains("/Logs/Homebrew") { return .logs }
            if path.contains("/Cellar/") || path.contains("/Caskroom/") { return .oldVersions }
            return .other
        }
    }

    public struct Group: Identifiable, Hashable, Sendable {
        public let category: Category
        public let items: [Item]

        public var id: Category { category }

        /// Sum of the sizes brew listed for this group.
        public var bytes: Int64 {
            items.compactMap(\.bytes).reduce(0, +)
        }
    }
}

// MARK: - Item

extension CleanupPlan {

    public struct Item: Identifiable, Hashable, Sendable {
        /// "node 26.5.0" for an old version, the file name for a download,
        /// the formula name for an unused dependency.
        public let title: String
        public let path: String?
        public let bytes: Int64?
        public let category: Category

        public var id: String { path ?? "\(category.rawValue):\(title)" }

        public init(title: String, path: String?, bytes: Int64?, category: Category) {
            self.title = title
            self.path = path
            self.bytes = bytes
            self.category = category
        }

        /// Parses one removal line:
        /// `Would remove: /path (12 files, 4.6MB)`, `Removing: /path... (4.6MB)`,
        /// `Would remove (empty directory): /path`,
        /// `Would prune 3 files from: /path`.
        init?(line: String, cachePath: String?) {
            let prefixes = ["Would remove", "Removing", "Would prune", "Pruning"]
            guard prefixes.contains(where: line.hasPrefix),
                  let colon = line.range(of: ": ")
            else { return nil }

            var remainder = String(line[colon.upperBound...])
            var bytes: Int64?
            if remainder.hasSuffix(")"), let open = remainder.range(of: " (", options: .backwards) {
                let details = remainder[open.upperBound..<remainder.index(before: remainder.endIndex)]
                bytes = details.split(separator: ",").last.flatMap {
                    UpgradePlan.parseSize($0.trimmingCharacters(in: .whitespaces))
                }
                remainder = String(remainder[..<open.lowerBound])
            }
            let path = remainder.hasSuffix("...") ? String(remainder.dropLast(3)) : remainder
            let category = Category.of(path: path, cachePath: cachePath)

            self.init(
                title: Self.title(for: path, category: category, line: line),
                path: path,
                bytes: bytes,
                category: category
            )
        }

        /// A readable name: `name version` inside the Cellar or Caskroom,
        /// "3 files in bootsnap" for a prune, otherwise the file name.
        private static func title(for path: String, category: Category, line: String) -> String {
            let components = path.split(separator: "/").map(String.init)
            let fileName = components.last ?? path
            let words = line.split(separator: " ")
            if line.hasPrefix("Would prune") || line.hasPrefix("Pruning"),
               let count = words.firstIndex(where: { $0.first?.isNumber == true }),
               count + 1 < words.count {
                return "\(words[count]) \(words[count + 1]) in \(fileName)"
            }
            if category == .oldVersions,
               let root = components.lastIndex(where: { $0 == "Cellar" || $0 == "Caskroom" }),
               components.count == root + 3 {
                return "\(components[root + 1]) \(components[root + 2])"
            }
            return fileName
        }
    }
}
