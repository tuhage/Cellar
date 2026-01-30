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
            } else {
                graphContent
            }
        }
        .navigationTitle("Dependencies")
        .searchable(text: $store.searchQuery, prompt: "Filter packages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadGraph() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
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

    @ViewBuilder
    private var graphContent: some View {
        if let graph = store.graph {
            HSplitView {
                nodeList(graph: graph)
                    .frame(minWidth: 280, idealWidth: 350)

                detailPanel
                    .frame(minWidth: 300, idealWidth: 400)
            }
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
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Stats Row

    private func statsRow(graph: DependencyGraph) -> some View {
        HStack(spacing: 12) {
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

// MARK: - DependencyNodeRow

/// A single row in the dependency list showing a package name, dependency count,
/// and badges for orphan/leaf status.
private struct DependencyNodeRow: View {
    let node: DependencyNode

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
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
        .padding(.vertical, 2)
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
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                dependenciesSection
                dependentsSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .font(.title2)
                    .foregroundStyle(.tint)

                Text(node.name)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            HStack(spacing: 8) {
                if node.isOrphan {
                    StatusBadge(text: "Orphan", color: .orange)
                }
                if node.isLeaf {
                    StatusBadge(text: "Leaf", color: .green)
                }
                if !node.isOrphan && !node.isLeaf {
                    StatusBadge(text: "Intermediate", color: .blue)
                }

                Text("\(node.connectionCount) connections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Dependencies Section

    private var dependenciesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "Dependencies",
                count: node.dependencies.count,
                systemImage: "arrow.down.circle",
                color: .blue
            )

            if node.dependencies.isEmpty {
                Text("No dependencies \u{2014} this is a leaf package.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                ForEach(node.dependencies, id: \.self) { dep in
                    DependencyLinkButton(name: dep, onTap: onNavigate)
                }
            }
        }
    }

    // MARK: Dependents Section

    private var dependentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "Used By",
                count: node.dependents.count,
                systemImage: "arrow.up.circle",
                color: .purple
            )

            if node.dependents.isEmpty {
                Text("Nothing depends on this package.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                ForEach(node.dependents, id: \.self) { dep in
                    DependencyLinkButton(name: dep, onTap: onNavigate)
                }
            }
        }
    }

    // MARK: Section Header

    private func sectionHeader(
        title: String,
        count: Int,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(title)
                .fontWeight(.semibold)
            Text("(\(count))")
                .foregroundStyle(.secondary)
        }
        .font(.headline)
    }
}

// MARK: - DependencyLinkButton

/// A clickable row that navigates to a dependency/dependent node.
private struct DependencyLinkButton: View {
    let name: String
    let onTap: (String) -> Void

    var body: some View {
        Button {
            onTap(name)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
