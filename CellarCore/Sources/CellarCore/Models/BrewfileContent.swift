import Foundation

// MARK: - BrewfileContent

/// Parsed representation of a Brewfile: every `keyword "name"` entry, in
/// file order. Entries Cellar has no dedicated group for are kept as
/// `.other` instead of being dropped.
public struct BrewfileContent: Sendable, Equatable {

    // MARK: Entry

    public struct Entry: Identifiable, Sendable, Equatable, Hashable {

        /// The entry types `brew bundle` understands. Anything else lands in
        /// `.other`, keeping its keyword.
        public enum Kind: String, CaseIterable, Sendable {
            case tap, brew, cask, mas, vscode, go, cargo, whalebrew, other
        }

        /// The Brewfile keyword, such as `brew` or `npm`.
        public let keyword: String
        public let name: String
        /// The line that declares this entry; empty when Cellar can't write
        /// one (an item reported by brew under an unfamiliar heading).
        public let rawLine: String

        public var id: String { "\(keyword):\(name)" }
        public var kind: Kind { Kind(rawValue: keyword) ?? .other }

        public init(keyword: String, name: String, rawLine: String) {
            self.keyword = keyword
            self.name = name
            self.rawLine = rawLine
        }

        /// An entry with the line `brew bundle dump` would write for it.
        public init(keyword: String, name: String) {
            self.init(keyword: keyword, name: name, rawLine: "\(keyword) \"\(name)\"")
        }

        /// Whether this entry names `formula`, written short (`foo`) or
        /// tap-qualified (`user/tap/foo`).
        public func matches(_ formula: Formula) -> Bool {
            kind == .brew && (name == formula.name || name == formula.fullName)
        }

        /// Whether this entry names `cask`, written short or tap-qualified.
        public func matches(_ cask: Cask) -> Bool {
            kind == .cask && (name == cask.token || name == cask.fullToken)
        }
    }

    // MARK: Data

    public let entries: [Entry]

    // MARK: Computed

    public var isEmpty: Bool { entries.isEmpty }

    public func entries(of kind: Entry.Kind) -> [Entry] {
        entries.filter { $0.kind == kind }
    }

    public func contains(keyword: String, name: String) -> Bool {
        entries.contains { $0.keyword == keyword && $0.name == name }
    }

    // MARK: Init

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public static let empty = BrewfileContent(entries: [])

    // MARK: Parse

    /// Parses Brewfile text. A line counts as an entry when it is a keyword
    /// followed by a quoted name (`brew "wget", restart_service: true`);
    /// comments, options such as `cask_args`, and Ruby control flow are skipped.
    public static func parse(from content: String) -> BrewfileContent {
        BrewfileContent(entries: content.components(separatedBy: .newlines).compactMap(entry(from:)))
    }

    private static func entry(from line: String) -> Entry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("#") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        guard parts.count == 2,
              parts[0].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
              let name = quotedName(from: String(parts[1]))
        else { return nil }
        return Entry(keyword: String(parts[0]), name: name, rawLine: trimmed)
    }

    /// The quoted value at the start of `raw`, without trailing options.
    /// An unterminated quote keeps the rest of the line readable.
    private static func quotedName(from raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        guard let quote = value.first, quote == "\"" || quote == "'" else { return nil }
        let contentStart = value.index(after: value.startIndex)
        let contentEnd = value[contentStart...].firstIndex(of: quote) ?? value.endIndex
        var name = String(value[contentStart..<contentEnd])
        if contentEnd == value.endIndex, let comma = name.firstIndex(of: ",") {
            name = String(name[..<comma])
        }
        name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    // MARK: Editing

    /// `text` with `lines` added at the end, keeping everything already there.
    public static func appending(_ lines: [String], to text: String) -> String {
        guard !lines.isEmpty else { return text }
        let separator = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
        return text + separator + lines.joined(separator: "\n") + "\n"
    }

    /// `text` without the lines that declare `entry`.
    public static func removing(_ entry: Entry, from text: String) -> String {
        text.components(separatedBy: "\n")
            .filter { line in
                let parsed = self.entry(from: line)
                return parsed?.keyword != entry.keyword || parsed?.name != entry.name
            }
            .joined(separator: "\n")
    }

    // MARK: Preview

    public static var preview: BrewfileContent {
        parse(from: """
        tap "homebrew/services"
        brew "wget"
        brew "git"
        brew "node"
        brew "python@3.12"
        cask "visual-studio-code"
        cask "firefox"
        mas "Xcode", id: 497799835
        vscode "ms-python.python"
        npm "pnpm"
        """)
    }
}
