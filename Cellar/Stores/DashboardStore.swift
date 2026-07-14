import Foundation
import Observation
import CellarCore
import WidgetKit

/// Manages the state for the dashboard view.
///
/// Builds a `SystemSummary` from the shared application stores. Provides
/// quick actions for common maintenance
/// tasks: upgrade all, cleanup, and health check.
@Observable
@MainActor
final class DashboardStore: LoadableStore {

    // MARK: Data

    var summary: SystemSummary?

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var actionStream: AsyncThrowingStream<String, Error>?
    var actionTitle: String?

    var isPerformingAction: Bool { actionStream != nil }

    // MARK: Dependencies

    private let service = BrewService.shared
    private let persistence = PersistenceService()
    private static let cacheMaxAge: TimeInterval = 300
    private static let cacheFile = "cache-dashboard.json"

    // MARK: Actions

    func restoreCachedSummary() {
        guard summary == nil else { return }
        summary = persistence.loadCached(
            SystemSummary.self,
            from: Self.cacheFile,
            maxAge: Self.cacheMaxAge
        )?.data
    }

    func update(
        formulae: [Formula],
        casks: [Cask],
        services: [BrewServiceItem],
        taps: [Tap]
    ) {
        let loadedSummary = SystemSummary.current(
            formulae: formulae,
            casks: casks,
            services: services,
            taps: taps
        )
        summary = loadedSummary
        persistence.saveToCache(loadedSummary, to: Self.cacheFile)
        writeWidgetSnapshot(summary: loadedSummary, services: services)
    }

    func cleanup() {
        performStreamingAction(title: "Cleaning Up") {
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
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: Private

    private func performStreamingAction(
        title: String,
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
