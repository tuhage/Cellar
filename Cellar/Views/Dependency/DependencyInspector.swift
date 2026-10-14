import SwiftUI
import CellarCore

/// Answers "why is this installed?" and "what happens if I remove it?" for
/// one package, from the loaded graph.
struct DependencyInspector: View {
    let node: DependencyNode
    let graph: DependencyGraph
    /// The installed package; `nil` while the package lists catch up.
    let package: PackageID?
    /// Installed and not busy with another operation.
    let canUninstall: Bool
    let uninstall: () -> Void

    @Environment(DependencyStore.self) private var store

    private var isRequested: Bool { graph.isRequested(node.name) }

    var body: some View {
        List {
            header
            whySection
            removalSection
            dependenciesSection
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text(node.name)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)

            DependencyBadges(node: node, graph: graph)

            HStack(spacing: Spacing.item) {
                if let package {
                    ShowPackageButton(package: package)
                }
                Button(role: .destructive, action: uninstall) {
                    Label("Uninstall\u{2026}", systemImage: "trash")
                }
                .disabled(!canUninstall)
                .help("Uninstall \(node.name)")
            }
            .controlSize(.small)
        }
        .padding(.vertical, Spacing.compact)
    }

    // MARK: - Why

    private var whySection: some View {
        Section("Why It’s Installed") {
            Text(reason)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            OutlineGroup(graph.dependentChains(of: node.name), children: \.children) { chain in
                packageLink(chain.name) {
                    if chain.isRequested {
                        StatusBadge(text: "Installed by You", color: .blue, icon: "person")
                    }
                }
            }
        }
    }

    private var reason: String {
        switch (isRequested, node.dependents.isEmpty) {
        case (true, true): "You installed it, and nothing else needs it."
        case (true, false): "You installed it. These packages need it too:"
        case (false, true): "Homebrew installed it as a dependency of a package that’s no longer installed. Nothing needs it now."
        case (false, false) where graph.isRemovable(node):
            "Homebrew installed it as a dependency, but only packages that are unused themselves still need it:"
        case (false, false): "Homebrew installed it because these packages need it:"
        }
    }

    // MARK: - Removal

    @ViewBuilder
    private var removalSection: some View {
        if node.dependents.isEmpty {
            let freed = graph.dependenciesFreed(byRemoving: node.name)
            Section("Removing It") {
                Text(freed.isEmpty
                    ? "Nothing else needs it, and none of its dependencies become unused."
                    : "Nothing else needs it. Uninstalling it leaves \(String.count(freed.count, "dependency")) unused:")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(freed, id: \.self) { name in
                    packageLink(name)
                }
            }
        } else {
            Section {
                Text("These packages need it and may stop working without it:")
                    .foregroundStyle(.secondary)
                ForEach(node.dependents, id: \.self) { name in
                    packageLink(name)
                }
            } header: {
                Text("Removing It Affects \(String.count(node.dependents.count, "Package"))")
            }
        }
    }

    // MARK: - Dependencies

    @ViewBuilder
    private var dependenciesSection: some View {
        let indirectCount = node.dependencies.count - node.directDependencies.count
        Section {
            if node.directDependencies.isEmpty {
                Text("It doesn’t need any other package.")
                    .foregroundStyle(.secondary)
            }
            ForEach(node.directDependencies, id: \.self) { name in
                packageLink(name)
            }
            if indirectCount > 0 {
                Text("Plus \(String.count(indirectCount, "dependency")) through these.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            CountedSectionHeader(title: "Depends On", systemImage: "arrow.down.circle", count: node.directDependencies.count)
        }
    }

    // MARK: - Helpers

    /// A package name that selects the package in the list.
    private func packageLink(_ name: String, @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        Button {
            store.select(name)
        } label: {
            HStack {
                Text(name)
                Spacer()
                trailing()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show \(name)")
    }

}

// MARK: - Preview

#Preview {
    let stores = DependencyStore.preview(in: AppStores())
    let graph = DependencyGraph.preview

    DependencyInspector(
        node: graph.node(named: "gettext")!,
        graph: graph,
        package: PackageID(kind: .formula, name: "gettext"),
        canUninstall: true,
        uninstall: {}
    )
    .environment(stores)
    .frame(width: 360, height: 700)
}
