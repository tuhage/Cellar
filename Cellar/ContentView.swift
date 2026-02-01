import SwiftUI
import CellarCore

struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard

    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(TapStore.self) private var tapStore
    @Environment(ResourceStore.self) private var resourceStore

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            if let selection {
                DetailView(item: selection, selection: $selection)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar.")
                )
            }
        }
        .urlSchemeHandler(selection: $selection)
        .task { await prefetchStores() }
    }

    /// Eagerly loads all brew-dependent stores on launch so every
    /// section has fresh data when the user navigates to it.
    private func prefetchStores() async {
        async let packages: () = packageStore.loadAll(forceRefresh: true)
        async let services: () = serviceStore.load(forceRefresh: true)
        async let taps: () = tapStore.load(forceRefresh: true)
        _ = await (packages, services, taps)

        await resourceStore.loadAll(services: serviceStore.services)
    }
}

private struct DetailView: View {
    let item: SidebarItem
    @Binding var selection: SidebarItem?

    var body: some View {
        switch item {
        case .dashboard:
            DashboardView(selection: $selection)
        case .formulae:
            FormulaListView()
        case .casks:
            CaskListView()
        case .services:
            ServiceListView()
        case .outdated:
            OutdatedView()
        case .brewfile:
            BrewfileView()
        case .taps:
            TapListView()
        case .dependencies:
            DependencyGraphView()
        case .resources:
            ResourceMonitorView()
        case .projects:
            ProjectListView()
        case .maintenance:
            MaintenanceView()
        }
    }
}

#Preview {
    ContentView()
        .environment(PackageStore())
        .environment(ServiceStore())
        .environment(DependencyStore())
        .environment(BrewfileStore())
        .environment(TapStore())
        .environment(ResourceStore())
        .environment(ProjectStore())
        .environment(MaintenanceStore())
}
