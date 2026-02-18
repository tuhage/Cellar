import Foundation
import Observation
import CellarCore

// MARK: - ServiceStore

/// Manages the state for Homebrew services.
///
/// Coordinates loading, filtering by status, and start/stop/restart
/// operations. Views bind to this store for the services list UI.
@Observable
@MainActor
final class ServiceStore {

    // MARK: Data

    var services: [BrewServiceItem] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var selectedServiceId: String?

    // MARK: Cache

    private let persistence = PersistenceService()
    private static let cacheMaxAge: TimeInterval = 300
    private static let cacheFile = "cache-services.json"

    // MARK: Computed

    var runningServices: [BrewServiceItem] {
        services.filter(\.isRunning)
    }

    var stoppedServices: [BrewServiceItem] {
        services.filter { !$0.isRunning }
    }

    var runningCount: Int {
        runningServices.count
    }

    // MARK: Actions

    /// Loads all Homebrew services.
    func load(forceRefresh: Bool = false) async {
        let (restored, needsFetch) = persistence.restoreIfNeeded(
            current: services, from: Self.cacheFile,
            maxAge: Self.cacheMaxAge, forceRefresh: forceRefresh
        )
        services = restored
        guard needsFetch else { return }

        isLoading = true
        errorMessage = nil
        do {
            try await refreshServices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Starts a service and reloads the service list.
    func start(_ service: BrewServiceItem) async {
        isLoading = true
        errorMessage = nil
        do {
            try await service.start()
            try await refreshServices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Stops a service and reloads the service list.
    func stop(_ service: BrewServiceItem) async {
        isLoading = true
        errorMessage = nil
        do {
            try await service.stop()
            try await refreshServices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Restarts a service and reloads the service list.
    func restart(_ service: BrewServiceItem) async {
        isLoading = true
        errorMessage = nil
        do {
            try await service.restart()
            try await refreshServices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: Private

    private func refreshServices() async throws {
        services = try await BrewServiceItem.all
        persistence.saveToCache(services, to: Self.cacheFile)
    }
}
