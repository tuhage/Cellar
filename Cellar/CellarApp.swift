import SwiftUI
import CellarCore
import CoreSpotlight

@main
struct CellarApp: App {
    @State private var packageStore = PackageStore()
    @State private var serviceStore = ServiceStore()
    @State private var dependencyStore = DependencyStore()
    @State private var brewfileStore = BrewfileStore()
    @State private var collectionStore = CollectionStore()
    @State private var resourceStore = ResourceStore()
    @State private var projectStore = ProjectStore()
    @State private var historyStore = HistoryStore()
    @State private var maintenanceStore = MaintenanceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(packageStore)
                .environment(serviceStore)
                .environment(dependencyStore)
                .environment(brewfileStore)
                .environment(collectionStore)
                .environment(resourceStore)
                .environment(projectStore)
                .environment(historyStore)
                .environment(maintenanceStore)
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }
                .onAppear { registerFinderSyncNotifications() }
        }
        .commands { AppCommands() }

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
            let name = String(identifier.dropFirst("formula:".count))
            packageStore.selectedFormulaId = name
        } else if identifier.hasPrefix("cask:") {
            let token = String(identifier.dropFirst("cask:".count))
            packageStore.selectedCaskId = token
        }
    }

    // MARK: - Finder Sync Notifications

    private func registerFinderSyncNotifications() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            forName: .init("com.tuhage.Cellar.stopService"),
            object: nil,
            queue: .main
        ) { notification in
            guard let serviceName = notification.userInfo?["serviceName"] as? String else { return }
            Task { @MainActor in
                guard let service = serviceStore.services.first(where: { $0.name == serviceName }) else { return }
                await serviceStore.stop(service)
            }
        }

        center.addObserver(
            forName: .init("com.tuhage.Cellar.startService"),
            object: nil,
            queue: .main
        ) { notification in
            guard let serviceName = notification.userInfo?["serviceName"] as? String else { return }
            Task { @MainActor in
                guard let service = serviceStore.services.first(where: { $0.name == serviceName }) else { return }
                await serviceStore.start(service)
            }
        }
    }
}
