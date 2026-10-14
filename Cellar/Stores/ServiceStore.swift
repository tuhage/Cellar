import Foundation
import Observation
import CellarCore

// MARK: - ServiceStore

/// Manages the state for Homebrew services.
///
/// Loads the services list, remembers which services the user hid, and runs
/// service actions through the `ActivityStore`.
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

    // MARK: Hidden Services

    private static let showsHiddenKey = "com.tuhage.Cellar.services.showsHidden"
    private static let hiddenServicesKey = "com.tuhage.Cellar.services.hiddenNames"

    /// Whether to show services the user has hidden.
    var showsHiddenServices: Bool {
        didSet { UserDefaults.standard.set(showsHiddenServices, forKey: Self.showsHiddenKey) }
    }

    /// Names the user has hidden via the context menu.
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

    var runningCount: Int {
        runningServices.count
    }

    var failedCount: Int {
        services.count(where: \.isError)
    }

    /// The list without the services the user hid, unless they asked to see them.
    var visibleServices: [BrewServiceItem] {
        guard !showsHiddenServices else { return services }
        return services.filter { !hiddenServiceNames.contains($0.name) }
    }

    var hiddenCount: Int {
        services.count { hiddenServiceNames.contains($0.name) }
    }

    var selectedService: BrewServiceItem? {
        guard let selectedServiceId else { return nil }
        return services.first { $0.id == selectedServiceId }
    }

    /// When the service's current process started, if it is running.
    func startDate(of service: BrewServiceItem) -> Date? {
        processStartDates[service.name]
    }

    func isHidden(_ service: BrewServiceItem) -> Bool {
        hiddenServiceNames.contains(service.name)
    }

    // MARK: Init

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
        let defaults = UserDefaults.standard
        self.showsHiddenServices = defaults.bool(forKey: Self.showsHiddenKey)
        self.hiddenServiceNames = Set(defaults.stringArray(forKey: Self.hiddenServicesKey) ?? [])
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

    // MARK: Loading

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

    // MARK: Actions

    /// Services registered under `root` ask for an administrator password.
    func start(_ service: BrewServiceItem) async {
        await perform(.serviceStart(name: service.name)) {
            try await service.start()
        }
    }

    /// Starts the service for this session without registering it at login.
    func runOnce(_ service: BrewServiceItem) async {
        await perform(.serviceRun(name: service.name)) {
            try await service.runOnce()
        }
    }

    /// Stops the service; with `keepRegistered` it still starts at next login.
    func stop(_ service: BrewServiceItem, keepRegistered: Bool = false) async {
        await perform(.serviceStop(name: service.name)) {
            try await service.stop(keepRegistered: keepRegistered)
        }
    }

    func restart(_ service: BrewServiceItem) async {
        await perform(.serviceRestart(name: service.name)) {
            try await service.restart()
        }
    }

    /// Restarts the services together. Root services share one password
    /// prompt instead of asking once per service.
    func restart(_ services: [BrewServiceItem]) async {
        let idle = services.filter { !activityStore.isActive(.package($0.name)) }
        let rootServices = idle.filter(\.requiresRoot)
        let rootRestart = rootServices.isEmpty ? nil : Task {
            try await BrewServiceItem.restartAsRoot(rootServices)
        }

        await withTaskGroup(of: Void.self) { group in
            for service in idle {
                group.addTask {
                    await self.restart(service, sharing: rootRestart)
                }
            }
        }
        await load(forceRefresh: true)
    }

    /// One service's part of a batch restart, tracked as its own activity.
    /// Root services wait for the shared privileged restart.
    private func restart(_ service: BrewServiceItem, sharing rootRestart: Task<Void, Error>?) async {
        // Retrying reruns the restart alone; the shared one has finished.
        let retry = ActivityStore.Retry.custom { _ in await self.restart(service) }
        await perform(.serviceRestart(name: service.name), reload: false, retry: retry) {
            guard service.requiresRoot, let rootRestart else {
                return try await service.restart()
            }
            try await withTaskCancellationHandler {
                try await rootRestart.value
            } onCancel: {
                rootRestart.cancel()
            }
        }
    }

    /// Kills the process with SIGKILL, for a service that won't stop.
    func forceQuit(_ service: BrewServiceItem) async {
        await perform(.serviceForceQuit(name: service.name)) {
            try await service.forceQuit()
        }
    }

    // MARK: Private

    /// Runs a service action as an activity, then reloads the list.
    private func perform(
        _ kind: BrewOperation.Kind,
        reload: Bool = true,
        retry: ActivityStore.Retry = .rerun,
        _ action: @escaping @MainActor () async throws -> Void
    ) async {
        await activityStore.perform(kind, retry: retry) { _ in
            try await action()
            if reload {
                await self.load(forceRefresh: true)
            }
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
