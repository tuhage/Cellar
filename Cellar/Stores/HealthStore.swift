import Foundation
import Observation

// MARK: - HealthStore

/// Manages the state for Homebrew health diagnostics.
///
/// Runs `brew doctor` and `brew missing` to detect system issues,
/// then parses the output into structured `HealthCheck` items.
@Observable
@MainActor
final class HealthStore {

    // MARK: Data

    var checks: [HealthCheck] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?

    // MARK: Computed

    /// The system is healthy when no critical or warning issues exist.
    var isHealthy: Bool {
        !checks.contains { $0.severity == .critical || $0.severity == .warning }
    }

    /// Checks grouped by severity, sorted from most severe to least.
    var checksBySeverity: [(severity: HealthSeverity, checks: [HealthCheck])] {
        let grouped = Dictionary(grouping: checks, by: \.severity)
        return grouped
            .sorted { $0.key < $1.key }
            .map { (severity: $0.key, checks: $0.value) }
    }

    // MARK: Dependencies

    private let service: BrewService

    init(service: BrewService = BrewService()) {
        self.service = service
    }

    // MARK: Actions

    func runDiagnostics() async {
        isLoading = true
        errorMessage = nil
        checks = []

        do {
            async let doctorOutput = service.doctor()
            async let missingOutput = service.missing()

            let doctor = try await doctorOutput
            let missing = try await missingOutput

            var results: [HealthCheck] = []
            results.append(contentsOf: parseDoctorOutput(doctor))
            results.append(contentsOf: parseMissingOutput(missing))

            // Sort by severity (critical first)
            checks = results.sorted { $0.severity < $1.severity }

            // If nothing was found, add an info check confirming health
            if checks.isEmpty {
                checks = [
                    HealthCheck(
                        category: .other,
                        severity: .info,
                        title: "Your system is ready to brew",
                        description: "No issues were found during the health check."
                    )
                ]
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Parsing

    /// Parses the output from `brew doctor` into `HealthCheck` items.
    ///
    /// `brew doctor` output consists of "Warning:" blocks separated by blank lines.
    /// Each block starts with "Warning: <message>" followed by optional detail lines.
    private func parseDoctorOutput(_ output: String) -> [HealthCheck] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Your system is ready to brew." else {
            return []
        }

        // Split on "Warning:" boundaries
        let warningPrefix = "Warning: "
        let blocks = trimmed.components(separatedBy: "\n\n")

        var results: [HealthCheck] = []

        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard let firstLine = lines.first else { continue }

            // Extract the title from the first "Warning:" line
            let title: String
            let isWarning: Bool
            if firstLine.hasPrefix(warningPrefix) {
                title = String(firstLine.dropFirst(warningPrefix.count))
                isWarning = true
            } else if firstLine.hasPrefix("Error: ") {
                title = String(firstLine.dropFirst("Error: ".count))
                isWarning = false
            } else {
                // Not a recognized block; treat as info
                title = firstLine
                isWarning = false
            }

            // Remaining lines form the description
            let descriptionLines = lines.dropFirst()
            let description = descriptionLines.isEmpty
                ? title
                : descriptionLines.joined(separator: "\n")

            let category = categorize(title: title)
            let severity: HealthSeverity = isWarning ? .warning : .critical

            results.append(
                HealthCheck(
                    category: category,
                    severity: severity,
                    title: title,
                    description: description,
                    solution: suggestSolution(for: category, title: title),
                    autoFixable: false
                )
            )
        }

        return results
    }

    /// Parses the output from `brew missing` into `HealthCheck` items.
    ///
    /// Each line of `brew missing` output is a formula with missing dependencies.
    private func parseMissingOutput(_ output: String) -> [HealthCheck] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lines = trimmed.split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        return lines.map { line in
            HealthCheck(
                category: .dependencies,
                severity: .warning,
                title: "Missing dependency",
                description: line,
                solution: "Run `brew install` for the missing dependency.",
                autoFixable: false
            )
        }
    }

    // MARK: - Categorization

    /// Maps a warning title to a health category based on keywords.
    private func categorize(title: String) -> HealthCategory {
        let lowered = title.lowercased()

        if lowered.contains("link") || lowered.contains("symlink") || lowered.contains("unlinked") {
            return .symlinks
        }
        if lowered.contains("depend") || lowered.contains("missing") {
            return .dependencies
        }
        if lowered.contains("permission") || lowered.contains("not writable") || lowered.contains("ownership") {
            return .permissions
        }
        if lowered.contains("conflict") || lowered.contains("shadow") {
            return .conflicts
        }
        if lowered.contains("outdated") || lowered.contains("xcode") || lowered.contains("command line tools") {
            return .outdated
        }
        return .other
    }

    /// Suggests a solution based on the category and title.
    private func suggestSolution(for category: HealthCategory, title: String) -> String? {
        switch category {
        case .symlinks:
            "Run `brew link <formula>` to create the necessary symlinks."
        case .dependencies:
            "Run `brew install` for the missing dependencies."
        case .permissions:
            "Fix permissions with `sudo chown -R $(whoami) <path>`."
        case .conflicts:
            "Review conflicting files and remove or rename the duplicates."
        case .outdated:
            if title.lowercased().contains("xcode") {
                "Update Xcode from the Mac App Store or install the latest Command Line Tools."
            } else {
                "Run `brew upgrade` to update outdated packages."
            }
        case .other:
            nil
        }
    }
}
