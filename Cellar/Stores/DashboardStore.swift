import Foundation
import Observation
import CellarCore
import WidgetKit

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
    var actionOutput: String?
    var isPerformingAction = false
    var activeActionLabel: String?

    // MARK: Dependencies

    private let service = BrewService()

    // MARK: Actions

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

            let loadedSummary = SystemSummary.current(
                formulae: formulae,
                casks: casks,
                services: services
            )
            summary = loadedSummary
            writeWidgetSnapshot(summary: loadedSummary, services: services)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upgradeAll() async {
        await performAction("Upgrading all packages") {
            for try await _ in service.upgradeAll() {}
            await load()
        }
    }

    func cleanup() async {
        await performAction("Cleaning up") {
            var output = ""
            for try await line in service.cleanup() {
                output += line
            }
            actionOutput = output.isEmpty ? "Nothing to clean up." : output
            await load()
        }
    }

    func healthCheck() async {
        await performAction("Running health check") {
            let output = try await service.doctor()
            actionOutput = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Your system is ready to brew."
                : output
        }
    }

    func dismissActionOutput() {
        actionOutput = nil
    }

    // MARK: Private

    private func performAction(_ label: String, body: () async throws -> Void) async {
        isPerformingAction = true
        activeActionLabel = label
        actionOutput = nil
        errorMessage = nil
        do {
            try await body()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
        activeActionLabel = nil
    }

    private func writeWidgetSnapshot(summary: SystemSummary, services: [BrewServiceItem]) {
        let snapshot = WidgetSnapshot.from(summary: summary, services: services)
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
