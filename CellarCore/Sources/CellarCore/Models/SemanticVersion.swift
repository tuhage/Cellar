import Foundation

/// A small SemVer-compatible value used for reliable update comparisons.
/// Missing core components are treated as zero (`1.2 == 1.2.0`).
public struct SemanticVersion: Comparable, Sendable {
    private let core: [Int]
    private let prerelease: [Identifier]?

    public init(_ value: String) {
        let withoutBuild = value.split(separator: "+", maxSplits: 1).first.map(String.init) ?? value
        let parts = withoutBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numeric = parts.first.map(String.init) ?? "0"
        self.core = numeric
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { Int($0) ?? 0 }
        self.prerelease = parts.count > 1
            ? parts[1].split(separator: ".").map(Identifier.init)
            : nil
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        compareCore(lhs.core, rhs.core) == 0 && lhs.prerelease == rhs.prerelease
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let coreResult = compareCore(lhs.core, rhs.core)
        if coreResult != 0 { return coreResult < 0 }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, _): return false
        case (_, nil): return true
        case let (left?, right?): return left.lexicographicallyPrecedes(right)
        }
    }

    private static func compareCore(_ lhs: [Int], _ rhs: [Int]) -> Int {
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        return 0
    }

    private enum Identifier: Comparable, Sendable {
        case numeric(Int)
        case text(String)

        init(_ value: Substring) {
            if let number = Int(value) { self = .numeric(number) }
            else { self = .text(String(value)) }
        }

        static func < (lhs: Identifier, rhs: Identifier) -> Bool {
            switch (lhs, rhs) {
            case let (.numeric(left), .numeric(right)): left < right
            case (.numeric, .text): true
            case (.text, .numeric): false
            case let (.text(left), .text(right)): left < right
            }
        }
    }
}
