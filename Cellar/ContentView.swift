import SwiftUI
import CellarCore

struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            if let selection {
                DetailView(item: selection)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar.")
                )
            }
        }
        .urlSchemeHandler(selection: $selection)
    }
}

private struct DetailView: View {
    let item: SidebarItem

    var body: some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .formulae:
            FormulaListView()
        case .casks:
            CaskListView()
        case .services:
            ServiceListView()
        case .outdated:
            OutdatedView()
        case .search:
            SearchView()
        case .brewfile:
            BrewfileView()
        case .health:
            HealthCheckView()
        case .security:
            SecurityAlertView()
        case .collections:
            CollectionListView()
        case .dependencies:
            DependencyGraphView()
        case .resources:
            ResourceMonitorView()
        case .history:
            HistoryView()
        case .projects:
            ProjectListView()
        case .comparison:
            ComparisonView()
        case .maintenance:
            MaintenanceView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environment(PackageStore())
        .environment(ServiceStore())
        .environment(DependencyStore())
        .environment(BrewfileStore())
        .environment(CollectionStore())
        .environment(ResourceStore())
        .environment(ProjectStore())
        .environment(HistoryStore())
        .environment(MaintenanceStore())
}

