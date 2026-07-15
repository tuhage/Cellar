import SwiftUI
import CellarCore

struct ContentView: View {
    @AppStorage("selectedSidebarItem") private var storedSelection: String = SidebarItem.dashboard.rawValue

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { SidebarItem(rawValue: storedSelection) },
            set: { newValue in storedSelection = (newValue ?? .dashboard).rawValue }
        )
    }
    @State private var isBrewInstalled = BrewProcess.isInstalled
    @State private var isQuickOpenPresented = false
    @State private var operationNotice: OperationNotice?
    @State private var announcedOperationIDs: Set<UUID> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(TapStore.self) private var tapStore
    @Environment(MaintenanceStore.self) private var maintenanceStore
    @Environment(ActivityStore.self) private var activityStore

    var body: some View {
        Group {
            if isBrewInstalled {
                mainContent
            } else {
                OnboardingView {
                    withAnimation { isBrewInstalled = true }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard !isBrewInstalled else { return }
            isBrewInstalled = BrewProcess.isInstalled
        }
    }

    private var mainContent: some View {
        NavigationSplitView {
            SidebarView(selection: selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            if let item = selection.wrappedValue {
                DetailView(item: item, selection: selection)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isQuickOpenPresented = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Quick Open (⌘K)")
                .accessibilityLabel("Quick Open")
            }

            ToolbarItem(placement: .primaryAction) {
                ActivityToolbarButton()
            }
        }
        .sheet(isPresented: $isQuickOpenPresented) {
            QuickOpenView(selection: selection, isPresented: $isQuickOpenPresented)
        }
        .overlay(alignment: .topTrailing) {
            if let operationNotice {
                OperationNoticeView(
                    notice: operationNotice,
                    showDetails: {
                        NotificationCenter.default.post(name: .openActivityPanel, object: nil)
                        self.operationNotice = nil
                    },
                    dismiss: { self.operationNotice = nil }
                )
                .padding(Spacing.section)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : AnimationToken.smooth, value: operationNotice)
        .onChange(of: activityStore.operations) { _, operations in
            guard let completed = operations.first(where: {
                !$0.isRunning && !announcedOperationIDs.contains($0.id)
            }) else { return }
            announcedOperationIDs.insert(completed.id)
            operationNotice = OperationNotice(operation: completed)
        }
        .task(id: operationNotice?.id) {
            guard operationNotice != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            operationNotice = nil
        }
        .urlSchemeHandler(selection: selection)
        .onReceive(NotificationCenter.default.publisher(for: .refreshAll)) { _ in
            guard isBrewInstalled else { return }
            Task { await refreshAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .upgradeAll)) { _ in
            guard isBrewInstalled else { return }
            packageStore.upgradeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cleanup)) { _ in
            guard isBrewInstalled else { return }
            Task { await maintenanceStore.runCleanup() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshServices)) { _ in
            guard isBrewInstalled else { return }
            Task { await serviceStore.load(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openQuickOpen)) { _ in
            isQuickOpenPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSidebarItem)) { notification in
            guard let rawValue = notification.userInfo?["item"] as? String,
                  let item = SidebarItem(rawValue: rawValue) else { return }
            selection.wrappedValue = item
        }
    }

    private func refreshAll() async {
        async let packages: () = packageStore.loadAll(forceRefresh: true)
        async let services: () = serviceStore.load(forceRefresh: true)
        async let taps: () = tapStore.load(forceRefresh: true)
        _ = await (packages, services, taps)
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
        .environment(ActivityStore())
}
