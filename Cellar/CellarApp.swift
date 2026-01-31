import SwiftUI
import CellarCore
import CoreSpotlight

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
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }
                .task { notificationObserver.register(serviceStore: serviceStore) }
        }
        .commands { AppCommands() }

        Settings {
            SettingsView()
        }

        MenuBarExtra("Cellar", systemImage: "mug") {
            MenuBarView()
                .environment(packageStore)
                .environment(serviceStore)
                .environment(maintenanceStore)
        }
        .menuBarExtraStyle(.menu)
    }

    // MARK: - Spotlight

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        if identifier.hasPrefix("formula:") {
            packageStore.selectedFormulaId = String(identifier.dropFirst("formula:".count))
        } else if identifier.hasPrefix("cask:") {
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

    private static func handleServiceNotification(
        _ notification: Notification,
        serviceStore: ServiceStore,
        action: @escaping (BrewServiceItem) async -> Void
    ) {
        guard let serviceName = notification.userInfo?["serviceName"] as? String else { return }
        Task { @MainActor in
            guard let service = serviceStore.services.first(where: { $0.name == serviceName }) else { return }
            await action(service)
        }
    }
}
