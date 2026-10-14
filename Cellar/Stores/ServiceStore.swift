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

    var services: [BrewServiceItem] = [] {
        didSet { processStartDates = Self.processStartDates(of: services) }
    }

    /// When each running service's process started, captured whenever the
    /// list changes so views don't query the kernel on every render.
    private var processStartDates: [String: Date] = [:]

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var selectedServiceId: String?

    // MARK: Dependencies

    let activityStore: ActivityStore
    private static let cache = CachePolicy(fileName: "cache-services.json")

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

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
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
        await load(
            cache: Self.cache,
            force: forceRefresh,
            failureMessage: "Services couldn’t be loaded."
        ) {
            try await BrewServiceItem.all
        } apply: { services in
            self.services = services
        }
    }

    /// Running services whose process started before their formula's
    /// current version was installed: they keep running the old build until
    /// restarted.
    func servicesNeedingRestart(formulae: [Formula]) -> [BrewServiceItem] {
        let installTimes = Dictionary(
            formulae.compactMap { formula in formula.installTime.map { (formula.name, $0) } },
            uniquingKeysWith: max
        )
        return services.filter { service in
            guard service.isRunning,
                  let startedAt = processStartDates[service.name],
                  let installedAt = installTimes[service.name]
            else { return false }
            return startedAt < installedAt
        }
    }

    /// Restarts each service in turn; root services prompt for a password.
    func restart(_ services: [BrewServiceItem]) async {
        for service in services {
            await restart(service)
        }
    }

    /// Services registered under `root` are managed with elevated privileges.
    func start(_ service: BrewServiceItem) async {
        await run(.serviceStart(name: service.name)) {
            try await service.start(privileged: service.requiresRoot)
        }
    }

    func stop(_ service: BrewServiceItem) async {
        await run(.serviceStop(name: service.name)) {
            try await service.stop(privileged: service.requiresRoot)
        }
    }

    func restart(_ service: BrewServiceItem) async {
        await run(.serviceRestart(name: service.name)) {
            try await service.restart(privileged: service.requiresRoot)
        }
    }

    func kill(_ service: BrewServiceItem) async {
        await run(.serviceForceQuit(name: service.name)) {
            try await service.kill()
        }
    }

    /// Uninstalls the formula backing a service.
    func uninstall(_ service: BrewServiceItem, force: Bool = false) async {
        await run(.uninstall(name: service.name, isCask: false)) {
            try await BrewService.shared.uninstall(service.name, force: force)
        }
    }

    // MARK: Private

    /// Runs a service action as an activity, then reloads the list.
    private func run(_ kind: BrewOperation.Kind, _ action: @escaping @MainActor () async throws -> Void) async {
        await activityStore.perform(kind) { _ in
            try await action()
            await self.load(forceRefresh: true)
        }
    }

    private static func processStartDates(of services: [BrewServiceItem]) -> [String: Date] {
        Dictionary(
            services.compactMap { service in
                service.isRunning ? service.processStartDate.map { (service.name, $0) } : nil
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
