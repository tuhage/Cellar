import Foundation
import Observation

// MARK: - DashboardStore

/// Manages the state for the dashboard view.
///
/// Loads formulae, casks, and services concurrently to build a
/// `SystemSummary`. Provides quick actions for common maintenance
/// tasks: upgrade all, cleanup, and health check.
@Observable
@MainActor
final class DashboardStore {

    // MARK: Data

    var summary: SystemSummary?

    // MARK: State

    var isLoading = false
    var errorMessage: String?

    /// Output from the most recent quick action (cleanup, health check).
    var actionOutput: String?

    /// Whether a quick action is currently running.
    var isPerformingAction = false

    /// Label for the currently running action.
    var activeActionLabel: String?

    // MARK: Dependencies

    private let service = BrewService()

    // MARK: Actions

    /// Loads all data concurrently and builds a system summary.
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let loadedFormulae = Formula.all
            async let loadedCasks = Cask.all
            async let loadedServices = BrewServiceItem.all

            let formulae = try await loadedFormulae
            let casks = try await loadedCasks
            let services = try await loadedServices

            summary = SystemSummary.current(
                formulae: formulae,
                casks: casks,
                services: services
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Upgrades all outdated packages and reloads.
    func upgradeAll() async {
        isPerformingAction = true
        activeActionLabel = "Upgrading all packages"
        errorMessage = nil
        do {
            for try await _ in service.upgradeAll() {}
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
        activeActionLabel = nil
    }

    /// Runs `brew cleanup` and captures the output.
    func cleanup() async {
        isPerformingAction = true
        activeActionLabel = "Cleaning up"
        actionOutput = nil
        errorMessage = nil
        do {
            var output = ""
            for try await line in service.cleanup() {
                output += line
            }
            actionOutput = output.isEmpty
                ? "Nothing to clean up."
                : output
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
        activeActionLabel = nil
    }

    /// Runs `brew doctor` and captures the output.
    func healthCheck() async {
        isPerformingAction = true
        activeActionLabel = "Running health check"
        actionOutput = nil
        errorMessage = nil
        do {
            let output = try await service.doctor()
            actionOutput = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Your system is ready to brew."
                : output
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
        activeActionLabel = nil
    }

    /// Clears the last action output.
    func dismissActionOutput() {
        actionOutput = nil
    }
}
