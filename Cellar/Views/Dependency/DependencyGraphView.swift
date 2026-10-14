import SwiftUI
import CellarCore

// MARK: - DependencyGraphView

/// Every installed package with why it's installed — by the user, or as a
/// dependency — and which dependencies nothing needs anymore. A list rather
/// than a drawn graph, so it stays readable with hundreds of packages.
struct DependencyGraphView: View {
    @Environment(DependencyStore.self) private var store
    @Environment(ActivityStore.self) private var activityStore
    @Environment(MaintenanceStore.self) private var maintenanceStore
    @FocusedValue(\.windowCommands) private var windowCommands

    @AppStorage(SettingsKey.showsInspector(.dependency)) private var isInspectorPresented = true
    @State private var uninstallRequest: UninstallRequest?

    var body: some View {
        @Bindable var store = store
        let graph = store.graph

        content(graph)
            .loadErrorBanner(for: store) { await store.load(forceRefresh: true) }
            .navigationTitle("Dependencies")
            .dataFreshness(store.lastUpdated)
            .searchable(text: $store.searchQuery, prompt: "Search packages")
            .searchScopes($store.searchScope) {
                ForEach(DependencySearchScope.allCases, id: \.self) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .toolbar { toolbar(graph) }
            .pageInspector(.dependency, isPresented: $isInspectorPresented) {
                inspector(graph)
            }
            .task(id: store.packageStore.lastUpdated) { await store.load() }
            .pageRefresh(isLoading: store.isLoading) { await store.load(forceRefresh: true) }
            .uninstallConfirmation($uninstallRequest)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ graph: DependencyGraph?) -> some View {
        if let graph, !graph.nodes.isEmpty {
            VStack(spacing: 0) {
                filterBar(graph)
                Divider()
                nodeList(graph)
            }
        } else if store.isLoading {
            LoadingView(message: "Reading dependencies\u{2026}")
        } else if let errorMessage = store.errorMessage {
            ErrorView(message: errorMessage) {
                Task { await store.load(forceRefresh: true) }
            }
        } else {
            EmptyStateView(
                title: "No Packages",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: "Installed packages and their dependencies will appear here.",
                actionTitle: "Check Again"
            ) {
                Task { await store.load(forceRefresh: true) }
            }
        }
    }

    /// Counts double as the filter, so "Removable 3" is one click away.
    private func filterBar(_ graph: DependencyGraph) -> some View {
        @Bindable var store = store

        return Picker("Show", selection: $store.filter) {
            ForEach(DependencyFilter.allCases, id: \.self) { filter in
                Text("\(filter.title) \(filter.count(in: graph))").tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.item)
    }

    @ViewBuilder
    private func nodeList(_ graph: DependencyGraph) -> some View {
        let nodes = store.visibleNodes(in: graph)
        if nodes.isEmpty {
            emptyFilterState
                .frame(maxHeight: .infinity)
        } else {
            List(nodes, selection: Binding(
                get: { store.selectedNodeName },
                set: { store.selectedNodeName = $0 }
            )) { node in
                DependencyRow(node: node, graph: graph, matches: store.matches(for: node), scope: store.searchScope)
                    .tag(node.name)
            }
            .listStyle(.inset)
            .contextMenu(forSelectionType: String.self) { names in
                if let name = names.first, let node = graph.node(named: name) {
                    nodeContextMenu(node)
                }
            } primaryAction: { names in
                store.selectedNodeName = names.first
                isInspectorPresented = true
            }
        }
    }

    @ViewBuilder
    private var emptyFilterState: some View {
        if !store.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView.search(text: store.searchQuery)
        } else {
            switch store.filter {
            case .removable:
                EmptyStateView(
                    title: "No Removable Packages",
                    systemImage: "checkmark.circle",
                    description: "Every dependency is still needed by a package you installed."
                )
            case .requested:
                EmptyStateView(title: "No Packages Installed by You", systemImage: "person")
            case .dependencies:
                EmptyStateView(title: "No Dependencies", systemImage: "link")
            case .all:
                EmptyStateView(title: "No Packages", systemImage: "shippingbox")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbar(_ graph: DependencyGraph?) -> some ToolbarContent {
        let removableCount = graph?.removableNodes.count ?? 0

        ToolbarItem(placement: .primaryAction) {
            Button {
                maintenanceStore.isAutoremovePreviewPresented = true
            } label: {
                Label(
                    removableCount > 0 ? "Remove \(removableCount) Unused\u{2026}" : "Remove Unused\u{2026}",
                    systemImage: "shippingbox.and.arrow.backward"
                )
            }
            .disabled(removableCount == 0 || maintenanceStore.isRunning)
            .help("Uninstall dependencies nothing needs anymore (brew autoremove)")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func nodeContextMenu(_ node: DependencyNode) -> some View {
        Button {
            store.select(node.name)
            isInspectorPresented = true
        } label: {
            Label("Why Is It Installed?", systemImage: "questionmark.circle")
        }

        if let package = store.package(named: node.name) {
            ShowPackageButton(package: package.id)
        }

        Divider()

        Button(role: .destructive) {
            requestUninstall(node.name)
        } label: {
            Label("Uninstall\u{2026}", systemImage: "trash")
        }
        .disabled(!canUninstall(node.name))
    }

    // MARK: - Inspector

    @ViewBuilder
    private func inspector(_ graph: DependencyGraph?) -> some View {
        if let graph, let name = store.selectedNodeName, let node = graph.node(named: name) {
            DependencyInspector(
                node: node,
                graph: graph,
                package: store.package(named: name)?.id,
                canUninstall: canUninstall(name),
                uninstall: { requestUninstall(name) }
            )
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text("Select a package to see why it’s installed and what needs it.")
            )
        }
    }

    // MARK: - Uninstall

    private func canUninstall(_ name: String) -> Bool {
        store.package(named: name) != nil && !activityStore.isActive(.package(name))
    }

    /// Uninstalls through the package pages' confirmation, which lists the
    /// packages that still need it.
    private func requestUninstall(_ name: String) {
        uninstallRequest = store.package(named: name).map { UninstallRequest(packages: [$0]) }
    }
}

// MARK: - Titles

extension DependencySearchScope {
    var title: String {
        switch self {
        case .name: "Name"
        case .dependsOn: "Depends On"
        case .usedBy: "Used By"
        }
    }
}

extension DependencyFilter {
    var title: String {
        switch self {
        case .all: "All"
        case .requested: "Installed by You"
        case .dependencies: "Dependencies"
        case .removable: "Removable"
        }
    }

    func count(in graph: DependencyGraph) -> Int {
        graph.nodes.count(where: { includes($0, in: graph) })
    }
}

// MARK: - Preview

#Preview {
    let stores = DependencyStore.preview(in: AppStores(), selecting: "openssl@3")

    NavigationStack {
        DependencyGraphView()
            .environment(stores)
    }
    .frame(width: 960, height: 600)
}
