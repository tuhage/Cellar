import SwiftUI
import CellarCore

// MARK: - DependencyGraphView

/// Displays the full dependency graph for all installed Homebrew formulae.
///
/// Layout:
/// - Top stats row (total packages, orphans, leaves, most depended)
/// - Searchable, filterable list of packages with expandable dependency trees
/// - Selecting a package shows a detail panel with dependents and dependencies
struct DependencyGraphView: View {
    @Environment(DependencyStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.graph == nil {
                LoadingView(message: "Analyzing dependencies\u{2026}")
            } else if let errorMessage = store.errorMessage, store.graph == nil {
                ErrorView(message: errorMessage) {
                    Task { await store.loadGraph() }
                }
            } else if store.graph == nil {
                EmptyStateView(
                    title: "No Dependencies",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: "Could not load dependency information."
                )
            } else if let graph = store.graph {
                graphContent(graph: graph)
            }
        }
        .navigationTitle("Dependencies")
        .searchable(text: $store.searchQuery, prompt: "Filter packages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.isLoading) {
                    await store.loadGraph()
                }
            }

            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $store.showOrphansOnly) {
                    Label("Orphans Only", systemImage: "exclamationmark.triangle")
                }
                .toggleStyle(.button)
                .help("Show only orphan packages (nothing depends on them)")
            }
        }
        .task(id: "refresh") {
            await store.loadGraph()
        }
    }

    // MARK: - Content

    private func graphContent(graph: DependencyGraph) -> some View {
        HSplitView {
            nodeList(graph: graph)
                .frame(minWidth: 280, idealWidth: 350)

            detailPanel
                .frame(minWidth: 250, idealWidth: 320, maxWidth: 400)
        }
    }

    // MARK: - Node List

    private func nodeList(graph: DependencyGraph) -> some View {
        VStack(spacing: 0) {
            statsRow(graph: graph)
                .padding()

            Divider()

            if store.filteredNodes.isEmpty {
                ContentUnavailableView.search(text: store.searchQuery)
                    .frame(maxHeight: .infinity)
            } else {
                List(store.filteredNodes, selection: Binding(
                    get: { store.selectedNodeName },
                    set: { store.selectedNodeName = $0 }
                )) { node in
                    DependencyNodeRow(node: node)
                        .tag(node.name)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Stats Row

    private func statsRow(graph: DependencyGraph) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sectionContent) {
            StatCardView(
                title: "Packages",
                value: "\(graph.totalPackages)",
                systemImage: "shippingbox",
                color: .blue
            )
            StatCardView(
                title: "Orphans",
                value: "\(graph.orphans.count)",
                systemImage: "exclamationmark.triangle",
                color: .orange
            )
            StatCardView(
                title: "Leaves",
                value: "\(graph.leaves.count)",
                systemImage: "leaf",
                color: .green
            )
            StatCardView(
                title: "Edges",
                value: "\(graph.totalEdges)",
                systemImage: "arrow.triangle.branch",
                color: .purple
            )
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let node = store.selectedNode {
            DependencyDetailView(node: node) { name in
                store.select(name)
            }
        } else {
            ContentUnavailableView(
                "Select a Package",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text("Choose a package to see its dependency details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - DependencyNode Appearance

private extension DependencyNode {
    var color: Color {
        if isOrphan { return .orange }
        if isLeaf { return .green }
        return .blue
    }

    var icon: String {
        if isOrphan { return "exclamationmark.triangle" }
        if isLeaf { return "leaf" }
        return "shippingbox"
    }
}

// MARK: - DependencyNodeRow

/// A single row in the dependency list showing a package name, dependency count,
/// and badges for orphan/leaf status.
private struct DependencyNodeRow: View {
    let node: DependencyNode

    var body: some View {
        HStack(spacing: Spacing.row) {
            Image(systemName: node.icon)
                .font(.caption)
                .foregroundStyle(node.color)
                .frame(width: IconSize.smallIcon, height: IconSize.smallIcon)
                .background(node.color.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.small))

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(node.name)
                    .fontWeight(.medium)

                HStack(spacing: Spacing.sectionContent) {
                    if !node.dependencies.isEmpty {
                        Label(
                            "\(node.dependencies.count) deps",
                            systemImage: "arrow.down.circle"
                        )
                    }
                    if !node.dependents.isEmpty {
                        Label(
                            "\(node.dependents.count) used by",
                            systemImage: "arrow.up.circle"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if node.isOrphan {
                StatusBadge(text: "Orphan", color: .orange)
            }
            if node.isLeaf {
                StatusBadge(text: "Leaf", color: .green)
            }
        }
        .padding(.vertical, Spacing.compact)
    }
}

// MARK: - DependencyDetailView

/// Shows full dependency detail for a selected node.
///
/// Displays the package name, status badges, and two sections:
/// - Dependencies: what this package requires
/// - Dependents: what requires this package
private struct DependencyDetailView: View {
    let node: DependencyNode
    let onNavigate: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header
                Divider()
                infoSection
                Divider()
                dependenciesSection
                Divider()
                dependentsSection
            }
            .padding(Spacing.section)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.detailElement) {
            Image(systemName: node.icon)
                .font(.title2)
                .foregroundStyle(node.color)
                .frame(width: IconSize.headerIcon, height: IconSize.headerIcon)
                .background(node.color.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.related) {
                Text(node.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack(spacing: Spacing.item) {
                    if node.isOrphan {
                        StatusBadge(text: "Orphan", color: .orange)
                    }
                    if node.isLeaf {
                        StatusBadge(text: "Leaf", color: .green)
                    }
                    if !node.isOrphan && !node.isLeaf {
                        StatusBadge(text: "Intermediate", color: .blue)
                    }
                }
            }
        }
    }

    // MARK: Info Section

    private var infoSection: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.cardPadding, verticalSpacing: Spacing.row) {
            GridRow {
                Text("Connections")
                    .foregroundStyle(.secondary)
                    .gridColumnAlignment(.trailing)
                Text("\(node.connectionCount)")
            }
            GridRow {
                Text("Dependencies")
                    .foregroundStyle(.secondary)
                Text("\(node.dependencies.count)")
            }
            GridRow {
                Text("Used By")
                    .foregroundStyle(.secondary)
                Text("\(node.dependents.count)")
            }
        }
        .font(.callout)
    }

    // MARK: Dependencies Section

    private var dependenciesSection: some View {
        packageListSection(
            title: "Dependencies",
            systemImage: "arrow.down.circle",
            color: .blue,
            packages: node.dependencies,
            emptyText: "No dependencies \u{2014} this is a leaf package."
        )
    }

    // MARK: Dependents Section

    private var dependentsSection: some View {
        packageListSection(
            title: "Used By",
            systemImage: "arrow.up.circle",
            color: .purple,
            packages: node.dependents,
            emptyText: "Nothing depends on this package."
        )
    }

    private func packageListSection(
        title: String,
        systemImage: String,
        color: Color,
        packages: [String],
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            SectionHeaderView(title: title, systemImage: systemImage, color: color) {
                Text("\(packages.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if packages.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                FlowLayout(spacing: Spacing.related) {
                    ForEach(packages, id: \.self) { name in
                        Button { onNavigate(name) } label: {
                            Text(name)
                                .font(.callout)
                                .fontDesign(.monospaced)
                                .chipInset()
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.small))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DependencyGraphView()
            .environment(previewDependencyStore())
    }
    .frame(width: 900, height: 600)
}

private func previewDependencyStore() -> DependencyStore {
    let store = DependencyStore()
    store.graph = DependencyGraph.preview
    store.selectedNodeName = "openssl@3"
    return store
}
