import Foundation

// MARK: - BrewfileContent

/// Parsed representation of a Brewfile's contents, categorised into
/// taps, formulae, and casks.
public struct BrewfileContent: Sendable, Equatable {

    // MARK: Entry

    public struct Entry: Identifiable, Sendable, Equatable, Hashable {
        public let id: String
        public let name: String
        public let rawLine: String

        public init(id: String, name: String, rawLine: String) {
            self.id = id
            self.name = name
            self.rawLine = rawLine
        }
    }

    // MARK: Data

    public let taps: [Entry]
    public let formulae: [Entry]
    public let casks: [Entry]

    // MARK: Computed

    public var totalItems: Int { taps.count + formulae.count + casks.count }
    public var isEmpty: Bool { totalItems == 0 }

    // MARK: Init

    public init(taps: [Entry], formulae: [Entry], casks: [Entry]) {
        self.taps = taps
        self.formulae = formulae
        self.casks = casks
    }

    // MARK: Empty

    public static let empty = BrewfileContent(taps: [], formulae: [], casks: [])

    // MARK: Parse

    /// Parses raw Brewfile text into categorised entries.
    ///
    /// Each non-empty, non-comment line is matched against its leading
    /// keyword (`tap`, `brew`, `cask`) and the quoted package name is
    /// extracted.
    public static func parse(from content: String) -> BrewfileContent {
        var taps: [Entry] = []
        var formulae: [Entry] = []
        var casks: [Entry] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard let keyword = parts.first else { continue }

            let name = extractName(from: parts.count > 1 ? String(parts[1]) : "")

            switch keyword {
            case "tap":
                taps.append(Entry(id: name, name: name, rawLine: trimmed))
            case "brew":
                formulae.append(Entry(id: name, name: name, rawLine: trimmed))
            case "cask":
                casks.append(Entry(id: name, name: name, rawLine: trimmed))
            default:
                break
            }
        }

        return BrewfileContent(taps: taps, formulae: formulae, casks: casks)
    }

    // MARK: Private

    /// Strips surrounding quotes and any trailing options from a Brewfile
    /// entry value, returning only the package name.
    private static func extractName(from raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)

        // Remove surrounding quotes
        if (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        } else if let quoteEnd = value.firstIndex(of: "\"") ?? value.firstIndex(of: "'") {
            // Handle: "name", restart_service: true
            let start = value.index(after: value.startIndex)
            if value.first == "\"" || value.first == "'" {
                value = String(value[start..<quoteEnd])
            }
        }

        // Strip trailing comma-separated options (e.g. `"wget", restart_service: true`)
        if let commaIndex = value.firstIndex(of: ",") {
            value = String(value[value.startIndex..<commaIndex])
        }

        return value.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Preview

    public static var preview: BrewfileContent {
        parse(from: """
        tap "homebrew/core"
        tap "homebrew/cask"
        brew "wget"
        brew "git"
        brew "node"
        brew "python@3.12"
        cask "visual-studio-code"
        cask "firefox"
        cask "iterm2"
        """)
    }
}
