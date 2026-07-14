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
final class ServiceStore: LoadableStore {

    // MARK: Data

    var services: [BrewServiceItem] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var selectedServiceId: String?

    // MARK: Activity

    var activityStore: ActivityStore?

    // MARK: Cache

    private let persistence = PersistenceService()
    private static let cacheMaxAge: TimeInterval = 300
    private static let cacheFile = "cache-services.json"

    // MARK: Filter State

    private static let showsUnusedKey = "com.tuhage.Cellar.services.showsUnused"
    private static let showsHiddenKey = "com.tuhage.Cellar.services.showsHidden"
    private static let hiddenServicesKey = "com.tuhage.Cellar.services.hiddenNames"

    /// Whether to show services with `.none` status (never started, formula metadata only).
    var showsUnusedServices: Bool {
        didSet { UserDefaults.standard.set(showsUnusedServices, forKey: Self.showsUnusedKey) }
    }

    /// Whether to show services the user has manually hidden.
    var showsHiddenServices: Bool {
        didSet { UserDefaults.standard.set(showsHiddenServices, forKey: Self.showsHiddenKey) }
    }

    /// Names the user has manually hidden via context menu.
    private(set) var hiddenServiceNames: Set<String> {
        didSet {
            let array = Array(hiddenServiceNames).sorted()
            UserDefaults.standard.set(array, forKey: Self.hiddenServicesKey)
        }
    }

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

    /// Filtered list for the view — respects unused and hidden filters.
    var visibleServices: [BrewServiceItem] {
        services.filter { service in
            if service.status == .none && !showsUnusedServices { return false }
            if hiddenServiceNames.contains(service.name) && !showsHiddenServices { return false }
            return true
        }
    }

    var unusedCount: Int {
        services.filter { $0.status == .none }.count
    }

    var hiddenCount: Int {
        services.filter { hiddenServiceNames.contains($0.name) }.count
    }

    // MARK: Init

    init() {
        let defaults = UserDefaults.standard
        self.showsUnusedServices = defaults.bool(forKey: Self.showsUnusedKey)
        self.showsHiddenServices = defaults.bool(forKey: Self.showsHiddenKey)
        let hiddenArray = defaults.stringArray(forKey: Self.hiddenServicesKey) ?? []
        self.hiddenServiceNames = Set(hiddenArray)
    }

    // MARK: Hide / Unhide

    func hide(_ service: BrewServiceItem) {
        hiddenServiceNames.insert(service.name)
    }

    func unhide(_ service: BrewServiceItem) {
        hiddenServiceNames.remove(service.name)
    }

    func unhideAll() {
        hiddenServiceNames.removeAll()
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
    /// Services registered under `root` are started with elevated privileges.
    func start(_ service: BrewServiceItem) async {
        guard activityStore?.isActive(target: service.name) != true else { return }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .serviceStart(name: service.name))
        do {
            try await service.start(privileged: service.requiresRoot)
            try await refreshServices()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            handleActionFailure(error, opID: opID)
        }
        isLoading = false
    }

    /// Stops a service and reloads the service list.
    /// Services registered under `root` are stopped with elevated privileges.
    func stop(_ service: BrewServiceItem) async {
        guard activityStore?.isActive(target: service.name) != true else { return }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .serviceStop(name: service.name))
        do {
            try await service.stop(privileged: service.requiresRoot)
            try await refreshServices()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            handleActionFailure(error, opID: opID)
        }
        isLoading = false
    }

    /// Force-kills a service (SIGKILL) and reloads the service list.
    func kill(_ service: BrewServiceItem) async {
        guard activityStore?.isActive(target: service.name) != true else {
            errorMessage = "\(service.name) is already in progress"
            return
        }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .serviceKill(name: service.name))
        do {
            try await service.kill()
            try await refreshServices()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            errorMessage = error.localizedDescription
            if let opID { activityStore?.setStatus(opID, .failed(reason: error.localizedDescription)) }
        }
        isLoading = false
    }

    /// Uninstalls the formula backing a service and reloads the service list.
    func uninstall(_ service: BrewServiceItem, force: Bool = false) async {
        guard activityStore?.isActive(target: service.name) != true else {
            errorMessage = "\(service.name) is already in progress"
            return
        }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .uninstall(name: service.name, isCask: false))
        do {
            try await BrewService.shared.uninstall(service.name, force: force)
            try await refreshServices()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            errorMessage = error.localizedDescription
            if let opID { activityStore?.setStatus(opID, .failed(reason: error.localizedDescription)) }
        }
        isLoading = false
    }

    /// Restarts a service and reloads the service list.
    /// Services registered under `root` are restarted with elevated privileges.
    func restart(_ service: BrewServiceItem) async {
        guard activityStore?.isActive(target: service.name) != true else { return }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .serviceRestart(name: service.name))
        do {
            try await service.restart(privileged: service.requiresRoot)
            try await refreshServices()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            handleActionFailure(error, opID: opID)
        }
        isLoading = false
    }

    // MARK: Private

    /// Surfaces an action failure. A user-dismissed admin prompt
    /// (`BrewError.cancelled`) is treated as a quiet cancellation rather
    /// than an error.
    private func handleActionFailure(_ error: Error, opID: UUID?) {
        if case BrewError.cancelled = error {
            if let opID { activityStore?.setStatus(opID, .cancelled) }
            return
        }
        errorMessage = error.localizedDescription
        if let opID { activityStore?.setStatus(opID, .failed(reason: error.localizedDescription)) }
    }

    private func refreshServices() async throws {
        services = try await BrewServiceItem.all
        persistence.saveToCache(services, to: Self.cacheFile)
    }
}
