import Foundation
import Observation

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
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            services = try await BrewServiceItem.all
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
            services = try await BrewServiceItem.all
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
            services = try await BrewServiceItem.all
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
            services = try await BrewServiceItem.all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Reloads the service list from Homebrew.
    func refresh() async {
        await load()
    }
}
