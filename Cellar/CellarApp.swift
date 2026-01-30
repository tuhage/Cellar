import SwiftUI

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
}
