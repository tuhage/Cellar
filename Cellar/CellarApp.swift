import SwiftUI
import CellarCore
import CoreSpotlight
import UserNotifications

@main
struct CellarApp: App {
    @State private var packageStore = PackageStore()
    @State private var serviceStore = ServiceStore()
    @State private var dependencyStore = DependencyStore()
    @State private var brewfileStore = BrewfileStore()
    @State private var tapStore = TapStore()
    @State private var resourceStore = ResourceStore()
    @State private var projectStore = ProjectStore()
    @State private var maintenanceStore = MaintenanceStore()
    @State private var updateStore = UpdateStore()
    @State private var activityStore = ActivityStore()
    @State private var notificationDelegate = ActivityNotificationDelegate()

    private let notificationObserver = FinderSyncNotificationObserver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(packageStore)
                .environment(serviceStore)
                .environment(dependencyStore)
                .environment(brewfileStore)
                .environment(tapStore)
                .environment(resourceStore)
                .environment(projectStore)
                .environment(maintenanceStore)
                .environment(updateStore)
                .environment(activityStore)
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }
                .task { notificationObserver.register(serviceStore: serviceStore) }
                .task { await updateStore.checkIfStale() }
                .task {
                    wireStores()
                    maintenanceStore.loadSettings()
                    maintenanceStore.loadReports()
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    await ActivityNotificationService.shared.requestPermission()
                    await runMaintenanceScheduler()
                }
                .onReceive(NotificationCenter.default.publisher(for: .checkForUpdates)) { _ in
                    Task { await updateStore.check() }
                }
                .onChange(of: activityStore.operations) {
                    for op in activityStore.operations {
                        guard !op.isRunning else { continue }
                        guard case .upgradeAll = op.kind else { continue }
                        ActivityNotificationService.shared.notifyCompletion(of: op)
                    }
                }
        }
        .defaultSize(width: 1320, height: 820)
        .commands { AppCommands() }

        Window("Keyboard Shortcuts", id: "keyboard-shortcuts") {
            KeyboardShortcutsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environment(updateStore)
        }

        MenuBarExtra("Cellar", systemImage: "mug") {
            MenuBarView()
                .environment(packageStore)
                .environment(serviceStore)
                .environment(maintenanceStore)
        }
        .menuBarExtraStyle(.menu)
    }

    // MARK: - Store Wiring

    private func wireStores() {
        packageStore.activityStore = activityStore
        serviceStore.activityStore = activityStore
        tapStore.activityStore = activityStore
        brewfileStore.activityStore = activityStore
        maintenanceStore.activityStore = activityStore
        projectStore.activityStore = activityStore
    }

    private func runMaintenanceScheduler() async {
        guard BrewProcess.isInstalled else { return }
        await maintenanceStore.checkSchedule()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(3_600))
            } catch {
                return
            }
            await maintenanceStore.checkSchedule()
        }
    }

    // MARK: - Spotlight

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        if identifier.hasPrefix("formula:") {
            UserDefaults.standard.set(SidebarItem.formulae.rawValue, forKey: "selectedSidebarItem")
            packageStore.selectedFormulaId = String(identifier.dropFirst("formula:".count))
        } else if identifier.hasPrefix("cask:") {
            UserDefaults.standard.set(SidebarItem.casks.rawValue, forKey: "selectedSidebarItem")
            packageStore.selectedCaskId = String(identifier.dropFirst("cask:".count))
        }
    }
}

// MARK: - Finder Sync Notification Observer

/// Registers distributed notification observers for Finder Sync service commands.
/// Uses a class to ensure observers are registered exactly once.
@MainActor
private final class FinderSyncNotificationObserver {
    private var isRegistered = false

    func register(serviceStore: ServiceStore) {
        guard !isRegistered else { return }
        isRegistered = true

        let center = DistributedNotificationCenter.default()

        center.addObserver(
            forName: .init("com.tuhage.Cellar.stopService"),
            object: nil,
            queue: .main
        ) { notification in
            Self.handleServiceNotification(notification, serviceStore: serviceStore) { service in
                await serviceStore.stop(service)
            }
        }

        center.addObserver(
            forName: .init("com.tuhage.Cellar.startService"),
            object: nil,
            queue: .main
        ) { notification in
            Self.handleServiceNotification(notification, serviceStore: serviceStore) { service in
                await serviceStore.start(service)
            }
        }
    }

    nonisolated private static func handleServiceNotification(
        _ notification: Notification,
        serviceStore: ServiceStore,
        action: @escaping @Sendable (BrewServiceItem) async -> Void
    ) {
        guard let serviceName = notification.userInfo?["serviceName"] as? String else { return }
        Task { @MainActor in
            if serviceStore.services.isEmpty {
                await serviceStore.load(forceRefresh: true)
            }
            guard let service = serviceStore.services.first(where: { $0.name == serviceName }) else {
                return
            }
            await action(service)
        }
    }
}
