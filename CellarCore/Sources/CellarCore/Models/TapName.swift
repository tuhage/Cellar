import Foundation

/// A tap name as typed when adding a tap — `user/repo` — and the GitHub
/// repository brew clones for it.
public struct TapName: Hashable, Sendable {

    public let user: String
    /// The repository without brew's `homebrew-` prefix.
    public let repo: String

    /// `nil` unless `text` is `user/repo` in the characters brew accepts.
    /// `user/homebrew-repo` is accepted too, as brew does.
    public init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).lowercased()
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard parts.count == 2, parts.allSatisfy(Self.isValidComponent) else { return nil }
        let repo = parts[1].hasPrefix(Self.repositoryPrefix)
            ? String(parts[1].dropFirst(Self.repositoryPrefix.count))
            : parts[1]
        guard Self.isValidComponent(repo) else { return nil }
        self.user = parts[0]
        self.repo = repo
    }

    public var name: String { "\(user)/\(repo)" }

    /// Maintained by the Homebrew project; any other tap runs code from
    /// whoever publishes it.
    public var isOfficial: Bool { user == "homebrew" }

    /// Where brew clones the tap from unless a custom URL is given.
    public var defaultRemote: URL {
        URL(string: "https://github.com/\(user)/\(Self.repositoryPrefix)\(repo)")!
    }

    // MARK: Validation

    private static let repositoryPrefix = "homebrew-"

    /// Letters, digits, `_` and `-`, like brew's own tap name pattern.
    private static func isValidComponent(_ component: String) -> Bool {
        !component.isEmpty && component.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    /// Whether `text` looks like a git remote brew can clone: a URL with a
    /// scheme (`https://`, `ssh://`, `file://`…) or scp-style `git@host:path`.
    public static func isValidRemote(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return false }
        if let url = URL(string: trimmed), let scheme = url.scheme, scheme.count > 1 {
            return url.host() != nil || !url.path().isEmpty
        }
        let scpStyle = trimmed.split(separator: ":", maxSplits: 1)
        return scpStyle.count == 2 && scpStyle[0].contains("@") && !scpStyle[1].isEmpty
    }
}
