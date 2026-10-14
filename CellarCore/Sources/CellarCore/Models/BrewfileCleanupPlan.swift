import Foundation

// MARK: - BrewfileCleanupPlan

/// What `brew bundle cleanup` would remove: everything installed that the
/// Brewfile doesn't list. Parsed from the command's dry run (without
/// `--force`), which changes nothing.
public struct BrewfileCleanupPlan: Sendable, Equatable {

    /// Each item carries the Brewfile line that would keep it installed, or
    /// an empty line when brew reported it under an unfamiliar heading.
    public let items: [BrewfileContent.Entry]

    public var isEmpty: Bool { items.isEmpty }

    public init(items: [BrewfileContent.Entry]) {
        self.items = items
    }

    /// brew's dry-run headings ("Would uninstall formulae:") and the Brewfile
    /// keyword of the items listed under each.
    private static let keywordsByHeading: [String: String] = [
        "Would uninstall formulae:": "brew",
        "Would uninstall casks:": "cask",
        "Would untap:": "tap",
        "Would uninstall Mac App Store apps:": "mas",
        "Would uninstall VSCode extensions:": "vscode",
        "Would uninstall Go packages:": "go",
        "Would uninstall Cargo packages:": "cargo",
        "Would uninstall npm packages:": "npm",
        "Would uninstall uv tools:": "uv",
        "Would uninstall Krew plugins:": "krew",
        "Would uninstall Flatpak packages:": "flatpak",
    ]

    /// Reads the item lists under each "Would uninstall …:" heading. The
    /// `brew cleanup` part of the dry run ("Would remove: …") is not about
    /// packages and is skipped.
    public static func parse(_ output: String) -> BrewfileCleanupPlan {
        var items: [BrewfileContent.Entry] = []
        var keyword: String?
        var isInPackageList = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Would uninstall ") || trimmed == "Would untap:" {
                keyword = keywordsByHeading[trimmed]
                isInPackageList = true
            } else if trimmed.hasPrefix("Would ") || trimmed.hasPrefix("==>") || trimmed.hasPrefix("Run `") {
                isInPackageList = false
            } else if isInPackageList, !trimmed.isEmpty {
                items.append(item(named: trimmed, keyword: keyword))
            }
        }
        return BrewfileCleanupPlan(items: items)
    }

    /// App Store apps are listed as "Name (id)" and need their id to be kept.
    private static func item(named name: String, keyword: String?) -> BrewfileContent.Entry {
        guard let keyword else {
            return BrewfileContent.Entry(keyword: BrewfileContent.Entry.Kind.other.rawValue, name: name, rawLine: "")
        }
        if keyword == "mas",
           let open = name.lastIndex(of: "("), name.hasSuffix(")") {
            let appName = name[..<open].trimmingCharacters(in: .whitespaces)
            let appID = name[name.index(after: open)..<name.index(before: name.endIndex)]
            return BrewfileContent.Entry(keyword: keyword, name: appName, rawLine: "mas \"\(appName)\", id: \(appID)")
        }
        return BrewfileContent.Entry(keyword: keyword, name: name)
    }

    /// Brewfile text that also keeps `kept` installed, for a cleanup that
    /// spares items the user unchecked.
    public static func brewfileText(_ text: String, keeping kept: [BrewfileContent.Entry]) -> String {
        BrewfileContent.appending(kept.map(\.rawLine).filter { !$0.isEmpty }, to: text)
    }
}
