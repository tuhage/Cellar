import Foundation

// MARK: - BrewfileCheck

/// Which Brewfile entries aren't installed, as reported by
/// `brew bundle check --verbose --no-upgrade`.
///
/// Cellar knows installed formulae, casks and taps itself, but not App Store
/// apps, VS Code extensions or other package managers — brew does.
public struct BrewfileCheck: Sendable, Equatable {

    /// `Entry.id`s of the missing entries.
    public let missingEntryIDs: Set<String>

    public init(missingEntryIDs: Set<String>) {
        self.missingEntryIDs = missingEntryIDs
    }

    public func isMissing(_ entry: BrewfileContent.Entry) -> Bool {
        missingEntryIDs.contains(entry.id)
    }

    /// brew's label for each entry type, as in "→ Formula wget needs to be installed."
    private static let keywordsByLabel: [String: String] = [
        "Tap": "tap",
        "Formula": "brew",
        "Cask": "cask",
        "App": "mas",
        "VSCode Extension": "vscode",
        "Go Package": "go",
        "Cargo Package": "cargo",
        "Whalebrew Image": "whalebrew",
        "npm Package": "npm",
        "uv Tool": "uv",
        "Krew Plugin": "krew",
        "Flatpak": "flatpak",
    ]

    /// Reads lines like "→ Cask firefox needs to be installed." Lines about
    /// linking or services aren't about missing packages and are ignored.
    public static func parse(_ output: String) -> BrewfileCheck {
        var ids: Set<String> = []
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("→ "),
                  trimmed.contains(" needs to be installed") || trimmed.hasSuffix(" needs to be tapped."),
                  let range = trimmed.range(of: " needs to be ")
            else { continue }
            let subject = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<range.lowerBound]
            if let (label, keyword) = keywordsByLabel.first(where: { subject.hasPrefix($0.key + " ") }) {
                ids.insert("\(keyword):\(subject.dropFirst(label.count + 1))")
            }
        }
        return BrewfileCheck(missingEntryIDs: ids)
    }
}
