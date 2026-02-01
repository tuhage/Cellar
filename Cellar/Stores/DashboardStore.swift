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
    private let persistence = PersistenceService()
    private static let cacheMaxAge: TimeInterval = 300

    // MARK: Actions

    func load(forceRefresh: Bool = false) async {
        // Show cached data immediately if we have nothing to display yet.
        if summary == nil, let cached = SystemSummary.loadFromCache() {
            summary = cached
        }

        // If cache is fresh and not forcing, skip the brew calls.
        if !forceRefresh, summary != nil,
           let cached = persistence.loadCached(Date.self, from: "cache-dashboard-timestamp.json", maxAge: Self.cacheMaxAge),
           cached.isFresh {
            return
        }

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
            loadedSummary.saveToCache()
            persistence.saveToCache(Date(), to: "cache-dashboard-timestamp.json")
            writeWidgetSnapshot(summary: loadedSummary, services: services)
        } catch {
            // Only show error if we have no data at all (no cache either).
            if summary == nil {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func upgradeAll() {
        performStreamingAction(title: "Upgrading All Packages", reloadAfter: true) {
            self.service.upgradeAll()
        }
    }

    func cleanup() {
        performStreamingAction(title: "Cleaning Up", reloadAfter: true) {
            self.service.cleanup()
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
                    await self.load()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: Private

    private func performStreamingAction(
        title: String,
        reloadAfter: Bool,
        stream: @escaping @Sendable () -> AsyncThrowingStream<String, Error>
    ) {
        actionTitle = title
        actionStream = AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in stream() {
                        continuation.yield(line)
                    }
                    continuation.finish()
                    if reloadAfter { await self.load() }
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
