import SwiftUI
import CellarCore
import CoreSpotlight
import UserNotifications

@main
struct CellarApp: App {
    @State private var stores = AppStores()
    @State private var notificationDelegate = ActivityNotificationDelegate()

    private let notificationObserver = FinderSyncNotificationObserver()

    var body: some Scene {
        WindowGroup(id: SceneID.main) {
            ContentView()
                .environment(stores)
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }
                .task { notificationObserver.register(serviceStore: stores.services) }
                .task { UNUserNotificationCenter.current().delegate = notificationDelegate }
                .task { await ActivityNotificationService.shared.requestPermission() }
                .onChange(of: stores.activity.operations) {
                    DockProgressService.shared.update(for: stores.activity.runningBatchOperation)
                    for operation in stores.activity.operations where !operation.isRunning {
                        ActivityNotificationService.shared.notifyCompletion(of: operation)
                    }
                }
                .onChange(of: stores.packages.lastUpdated) { updateWidget() }
                .onChange(of: stores.services.lastUpdated) { updateWidget() }
        }
        .defaultSize(width: 1320, height: 820)
        .commands { AppCommands(updateStore: stores.updates) }

        Window("Keyboard Shortcuts", id: SceneID.keyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environment(stores)
        }

        MenuBarExtra("Cellar", systemImage: "mug") {
            MenuBarView()
                .environment(stores)
        }
        .menuBarExtraStyle(.menu)
    }

    private func updateWidget() {
        WidgetSnapshotService.update(
            formulae: stores.packages.formulae,
            casks: stores.packages.casks,
            services: stores.services.services,
            taps: stores.taps.taps
        )
    }

    // MARK: - Spotlight

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        if identifier.hasPrefix("formula:") {
            UserDefaults.standard.set(SidebarItem.formulae.rawValue, forKey: "selectedSidebarItem")
            stores.packages.selectedFormulaId = String(identifier.dropFirst("formula:".count))
        } else if identifier.hasPrefix("cask:") {
            UserDefaults.standard.set(SidebarItem.casks.rawValue, forKey: "selectedSidebarItem")
            stores.packages.selectedCaskId = String(identifier.dropFirst("cask:".count))
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
