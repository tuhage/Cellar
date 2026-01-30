import Foundation

// MARK: - ComparisonResult

/// The result of comparing two sets of package names (typically from two Brewfiles).
///
/// Categorizes packages into three groups: only in source, only in target, and shared.
/// Provides a factory method to perform the comparison and a helper to parse Brewfile content.
struct ComparisonResult: Sendable {

    // MARK: Data

    let onlyInSource: [String]
    let onlyInTarget: [String]
    let inBoth: [String]
    let sourceLabel: String
    let targetLabel: String

    // MARK: Computed

    var totalDifferences: Int { onlyInSource.count + onlyInTarget.count }

    // MARK: - Compare

    /// Compares two arrays of package names, returning categorized results.
    static func compare(
        source: [String],
        target: [String],
        sourceLabel: String,
        targetLabel: String
    ) -> ComparisonResult {
        let sourceSet = Set(source)
        let targetSet = Set(target)

        let onlyInSource = source.filter { !targetSet.contains($0) }.sorted()
        let onlyInTarget = target.filter { !sourceSet.contains($0) }.sorted()
        let inBoth = source.filter { targetSet.contains($0) }.sorted()

        return ComparisonResult(
            onlyInSource: onlyInSource,
            onlyInTarget: onlyInTarget,
            inBoth: inBoth,
            sourceLabel: sourceLabel,
            targetLabel: targetLabel
        )
    }

    // MARK: - Brewfile Parsing

    /// Parses a Brewfile's content and extracts package names.
    ///
    /// Recognizes lines starting with `brew "`, `cask "`, and `tap "`.
    /// Returns the quoted name from each matching line.
    static func parseBrewfile(content: String) -> [String] {
        content
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

                // Match lines like: brew "name", cask "name", tap "name"
                for prefix in ["brew \"", "cask \"", "tap \""] {
                    if trimmed.hasPrefix(prefix) {
                        let afterPrefix = trimmed.dropFirst(prefix.count)
                        if let endQuote = afterPrefix.firstIndex(of: "\"") {
                            return String(afterPrefix[afterPrefix.startIndex..<endQuote])
                        }
                    }
                }
                return nil
            }
    }

    /// Reads a Brewfile at the given path and extracts package names.
    static func parseBrewfile(at path: String) throws -> [String] {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseBrewfile(content: content)
    }

    // MARK: - Export

    /// Generates a plain-text diff summary suitable for saving or sharing.
    func exportDiff() -> String {
        var lines: [String] = []

        lines.append("Brewfile Comparison")
        lines.append("Source: \(sourceLabel)")
        lines.append("Target: \(targetLabel)")
        lines.append(String(repeating: "-", count: 40))
        lines.append("")

        if !onlyInSource.isEmpty {
            lines.append("Only in \(sourceLabel) (\(onlyInSource.count)):")
            for name in onlyInSource {
                lines.append("  - \(name)")
            }
            lines.append("")
        }

        if !onlyInTarget.isEmpty {
            lines.append("Only in \(targetLabel) (\(onlyInTarget.count)):")
            for name in onlyInTarget {
                lines.append("  + \(name)")
            }
            lines.append("")
        }

        if !inBoth.isEmpty {
            lines.append("In Both (\(inBoth.count)):")
            for name in inBoth {
                lines.append("  = \(name)")
            }
            lines.append("")
        }

        lines.append(String(repeating: "-", count: 40))
        lines.append("Total differences: \(totalDifferences), Shared: \(inBoth.count)")

        return lines.joined(separator: "\n")
    }

    // MARK: Preview

    static var preview: ComparisonResult {
        ComparisonResult.compare(
            source: ["node", "yarn", "python@3.12", "openssl@3", "git"],
            target: ["node", "rust", "openssl@3", "git", "go"],
            sourceLabel: "Source Brewfile",
            targetLabel: "Target Brewfile"
        )
    }
}
