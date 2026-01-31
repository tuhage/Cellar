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
    var actionStream: AsyncThrowingStream<String, Error>?
    var actionTitle: String?

    var isPerformingAction: Bool { actionStream != nil }

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
            async let loadedTaps = Tap.all

            let formulae = try await loadedFormulae
            let casks = try await loadedCasks
            let services = try await loadedServices
            let taps = try await loadedTaps

            let loadedSummary = SystemSummary.current(
                formulae: formulae,
                casks: casks,
                services: services,
                taps: taps
            )
            summary = loadedSummary
            writeWidgetSnapshot(summary: loadedSummary, services: services)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upgradeAll() {
        actionTitle = "Upgrading All Packages"
        actionStream = AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in self.service.upgradeAll() {
                        continuation.yield(line)
                    }
                    continuation.finish()
                    await self.load()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func cleanup() {
        actionTitle = "Cleaning Up"
        actionStream = AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in self.service.cleanup() {
                        continuation.yield(line)
                    }
                    continuation.finish()
                    await self.load()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func healthCheck() {
        actionTitle = "Health Check"
        actionStream = AsyncThrowingStream { continuation in
            Task {
                do {
                    let output = try await self.service.doctor()
                    let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.yield(message.isEmpty ? "Your system is ready to brew." : message)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func dismissAction() {
        actionStream = nil
        actionTitle = nil
    }

    private func writeWidgetSnapshot(summary: SystemSummary, services: [BrewServiceItem]) {
        let snapshot = WidgetSnapshot.from(summary: summary, services: services)
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
