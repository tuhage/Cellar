import SwiftUI
import CellarCore

/// Every store of the app, created once and shared by all scenes, plus the
/// background work that keeps them current while Cellar runs.
@MainActor
final class AppStores {
    let activity: ActivityStore
    let notices = NoticeStore()
    let packages: PackageStore
    let services: ServiceStore
    let taps: TapStore
    let brewfiles: BrewfileStore
    let maintenance: MaintenanceStore
    let dependencies: DependencyStore
    let serviceMetrics = ServiceMetricsStore()
    let updates = UpdateStore(startingUpdater: !ProcessInfo.processInfo.isRunningForPreviews)

    private var isStarted = false

    /// Default seconds between service refreshes while Cellar is active.
    static let defaultServiceRefreshInterval: Double = 15
    private static let maintenanceCheckInterval: Duration = .seconds(3_600)

    /// Pass an activity store only to seed previews.
    init(activity: ActivityStore = ActivityStore()) {
        SettingsKey.migrateRenamedKeys()
        self.activity = activity
        packages = PackageStore(activityStore: activity)
        dependencies = DependencyStore(packageStore: packages)
        services = ServiceStore(activityStore: activity)
        taps = TapStore(activityStore: activity)
        brewfiles = BrewfileStore(activityStore: activity, packages: packages, services: services, taps: taps)
        maintenance = MaintenanceStore(activityStore: activity)
        maintenance.loadSettings()
        maintenance.loadReports()
        Self.removeObsoleteCaches()

        activity.onFinish = { [notices, services, updates] operation in
            notices.announce(operation)
            // Any upgrade, Brewfile install or reinstall may have replaced Cellar itself.
            updates.checkInstalledCopy()
            // Removing a formula removes its service, wherever it was uninstalled.
            if case .uninstall(_, isCask: false) = operation.kind, operation.status == .succeeded {
                Task { await services.load(forceRefresh: true) }
            }
        }
        activity.onChange = { [activity] in
            DockProgressService.shared.update(for: activity.runningBatchOperation)
        }
    }

    /// Caches written by earlier versions that nothing reads anymore.
    private static func removeObsoleteCaches() {
        let persistence = PersistenceService()
        for fileName in ["cache-formulae.json", "cache-casks.json", "cache-dashboard.json"] {
            try? persistence.delete(fileName: fileName)
        }
    }

    /// Loads the package, service and tap lists, then keeps services fresh,
    /// checks for package updates daily and runs scheduled maintenance until
    /// cancelled. Calling it again while it runs does nothing; call it after
    /// onboarding installs Homebrew.
    func start() async {
        guard !isStarted, BrewProcess.isInstalled else { return }
        isStarted = true
        defer { isStarted = false }

        await refreshAll(forceRefresh: false)
        async let servicePolling: Void = pollServices()
        async let scheduledWork: Void = runScheduledWork()
        _ = await (servicePolling, scheduledWork)
    }

    /// Reloads every list Cellar shows outside a single page.
    func refreshAll(forceRefresh: Bool = true) async {
        async let packages: Void = packages.load(forceRefresh: forceRefresh)
        async let services: Void = services.load(forceRefresh: forceRefresh)
        async let taps: Void = taps.load(forceRefresh: forceRefresh)
        _ = await (packages, services, taps)
    }

    /// Re-reads service status on the interval set in Settings, but only
    /// while Cellar is the active app — `brew services list` isn't free.
    private func pollServices() async {
        while !Task.isCancelled {
            let stored = UserDefaults.standard.double(forKey: SettingsKey.serviceRefreshInterval)
            let interval = stored > 0 ? stored : Self.defaultServiceRefreshInterval
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, NSApplication.shared.isActive else { continue }
            await services.load(forceRefresh: true)
        }
    }

    /// Checks hourly for overdue maintenance and the daily `brew update`.
    private func runScheduledWork() async {
        while !Task.isCancelled {
            await maintenance.checkSchedule()
            await packages.checkForUpdatesIfDue()
            try? await Task.sleep(for: Self.maintenanceCheckInterval)
        }
    }
}

// MARK: - Environment

extension View {
    /// Injects every store, so each scene and preview needs one line.
    func environment(_ stores: AppStores) -> some View {
        self
            .environment(stores.activity)
            .environment(stores.notices)
            .environment(stores.packages)
            .environment(stores.services)
            .environment(stores.taps)
            .environment(stores.brewfiles)
            .environment(stores.maintenance)
            .environment(stores.dependencies)
            .environment(stores.serviceMetrics)
            .environment(stores.updates)
            .environment(\.refreshAll, AsyncAction { await stores.refreshAll() })
            .environment(\.startBackgroundWork, AsyncAction { await stores.start() })
    }
}
