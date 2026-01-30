import Foundation
import Observation

// MARK: - SecurityStore

/// Manages the state for security alerts.
///
/// Analyzes already-loaded formulae and casks from `PackageStore` to
/// detect deprecated, disabled, and critically outdated packages.
/// Does not invoke any brew commands directly.
@Observable
@MainActor
final class SecurityStore {

    // MARK: Data

    var alerts: [SecurityAlert] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?

    // MARK: Computed

    /// Total number of security alerts.
    var alertCount: Int { alerts.count }

    /// Alerts grouped by severity, sorted from most severe to least.
    var alertsBySeverity: [(severity: SecuritySeverity, alerts: [SecurityAlert])] {
        let grouped = Dictionary(grouping: alerts, by: \.severity)
        return grouped
            .sorted { $0.key < $1.key }
            .map { (severity: $0.key, alerts: $0.value) }
    }

    /// Whether there are critical or high severity alerts.
    var hasCriticalAlerts: Bool {
        alerts.contains { $0.severity == .critical || $0.severity == .high }
    }

    // MARK: Actions

    /// Scans formulae and casks for security concerns.
    ///
    /// This method analyzes the already-loaded package data without
    /// making any additional brew CLI calls.
    func scan(formulae: [Formula], casks: [Cask]) async {
        isLoading = true
        errorMessage = nil

        var results: [SecurityAlert] = []

        // Scan formulae
        for formula in formulae {
            if formula.disabled {
                results.append(
                    SecurityAlert(
                        packageName: formula.name,
                        alertType: .disabled,
                        severity: .critical,
                        description: "The formula \"\(formula.name)\" has been disabled and will be removed in a future Homebrew release.",
                        recommendation: "Uninstall \(formula.name) and find an alternative package."
                    )
                )
            } else if formula.deprecated {
                results.append(
                    SecurityAlert(
                        packageName: formula.name,
                        alertType: .deprecated,
                        severity: .high,
                        description: "The formula \"\(formula.name)\" has been deprecated. It may stop receiving updates and security patches.",
                        recommendation: "Consider migrating to a supported alternative."
                    )
                )
            }

            if formula.outdated && (formula.deprecated || formula.disabled) {
                results.append(
                    SecurityAlert(
                        packageName: formula.name,
                        alertType: .outdatedCritical,
                        severity: .critical,
                        description: "The formula \"\(formula.name)\" is both outdated and \(formula.disabled ? "disabled" : "deprecated"). It may contain unpatched vulnerabilities.",
                        recommendation: "Uninstall \(formula.name) immediately and migrate to a supported package."
                    )
                )
            }
        }

        // Scan casks
        for cask in casks {
            if cask.disabled {
                results.append(
                    SecurityAlert(
                        packageName: cask.displayName,
                        alertType: .disabled,
                        severity: .critical,
                        description: "The cask \"\(cask.displayName)\" has been disabled and will be removed in a future Homebrew release.",
                        recommendation: "Uninstall \(cask.displayName) and find an alternative application."
                    )
                )
            } else if cask.deprecated {
                results.append(
                    SecurityAlert(
                        packageName: cask.displayName,
                        alertType: .deprecated,
                        severity: .high,
                        description: "The cask \"\(cask.displayName)\" has been deprecated. It may stop receiving updates and security patches.",
                        recommendation: "Consider migrating to a supported alternative."
                    )
                )
            }

            if cask.outdated && (cask.deprecated || cask.disabled) {
                results.append(
                    SecurityAlert(
                        packageName: cask.displayName,
                        alertType: .outdatedCritical,
                        severity: .critical,
                        description: "The cask \"\(cask.displayName)\" is both outdated and \(cask.disabled ? "disabled" : "deprecated"). It may contain unpatched vulnerabilities.",
                        recommendation: "Uninstall \(cask.displayName) immediately and migrate to a supported application."
                    )
                )
            }
        }

        // Sort by severity (critical first)
        alerts = results.sorted { $0.severity < $1.severity }
        isLoading = false
    }
}
