import Foundation
import Observation
import CellarCore

// MARK: - DependencyStore

/// Which installed packages need which, and why each one is installed.
///
/// The structure comes from `brew deps --installed`; whether the user
/// installed a package comes from the formulae `PackageStore` already holds,
/// so the page stays correct as packages are installed or removed.
@Observable
@MainActor
final class DependencyStore: LoadableStore {

    // MARK: Data

    /// Dependencies only; `graph` adds the install reasons.
    private var structure: DependencyGraph?

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var searchQuery = ""
    var searchScope: DependencySearchScope {
        didSet { UserDefaults.standard.set(searchScope.rawValue, forKey: SettingsKey.dependencySearchScope) }
    }
    var filter: DependencyFilter {
        didSet { UserDefaults.standard.set(filter.rawValue, forKey: SettingsKey.dependencyFilter) }
    }
    var selectedNodeName: String?

    // MARK: Dependencies

    let packageStore: PackageStore
    private static let cache = CachePolicy(fileName: "cache-dependencies.json")

    init(packageStore: PackageStore) {
        self.packageStore = packageStore
        let defaults = UserDefaults.standard
        searchScope = defaults.string(forKey: SettingsKey.dependencySearchScope).flatMap(DependencySearchScope.init) ?? .name
        filter = defaults.string(forKey: SettingsKey.dependencyFilter).flatMap(DependencyFilter.init) ?? .all
    }

    // MARK: Computed

    /// The dependencies plus why each package is installed. Formulae not
    /// installed on request are dependencies, as for `brew autoremove`.
    var graph: DependencyGraph? {
        guard var graph = structure else { return nil }
        graph.dependencyInstalls = Set(packageStore.formulae.filter { !$0.installedOnRequest }.map(\.name))
        return graph
    }

    /// The package lists changed after the dependencies were read, so
    /// packages were installed or removed since.
    private var isOutdated: Bool {
        guard let packagesUpdated = packageStore.lastUpdated, let lastUpdated else { return false }
        return packagesUpdated > lastUpdated
    }

    /// Nodes passing the filter and the search, in name order.
    func visibleNodes(in graph: DependencyGraph) -> [DependencyNode] {
        graph.nodes.filter { node in
            filter.includes(node, in: graph) && !matches(for: node).isEmpty
        }
    }

    /// Why `node` matches the search: the names containing the query, or
    /// its own name when there is no query.
    func matches(for node: DependencyNode) -> [String] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [node.name] }
        return node.matches(query, in: searchScope)
    }

    /// The installed formula or cask named `name` — the graph lists both
    /// alike.
    func package(named name: String) -> PackageType? {
        packageStore.package(PackageID(kind: .formula, name: name))
            ?? packageStore.package(PackageID(kind: .cask, name: name))
    }

    // MARK: Actions

    func load(forceRefresh: Bool = false) async {
        await load(
            cache: Self.cache,
            force: forceRefresh || isOutdated,
            failureMessage: "Dependencies couldn’t be loaded."
        ) {
            DependencyGraph.parse(try await BrewService.shared.depsInstalled())
        } apply: { dependencies in
            self.structure = DependencyGraph(dependencies: dependencies)
        }
    }

    func select(_ name: String) {
        selectedNodeName = name
    }
}

// MARK: - DependencyFilter

/// Which packages the dependency page lists.
enum DependencyFilter: String, CaseIterable {
    case all
    case requested
    case dependencies
    case removable

    func includes(_ node: DependencyNode, in graph: DependencyGraph) -> Bool {
        switch self {
        case .all: true
        case .requested: graph.isRequested(node.name)
        case .dependencies: !graph.isRequested(node.name)
        case .removable: graph.isRemovable(node)
        }
    }
}

extension DependencyStore {
    /// `stores.dependencies` showing `DependencyGraph.preview`, with the
    /// preview's install reasons as formulae, for previews.
    static func preview(in stores: AppStores, selecting name: String? = nil) -> AppStores {
        let graph = DependencyGraph.preview
        stores.packages.formulae = graph.nodes.map { node in
            Formula(
                name: node.name, fullName: node.name, desc: nil, license: nil,
                homepage: nil, version: "1.0", deprecated: false, disabled: false, outdated: false,
                pinned: false, dependencies: node.directDependencies, buildDependencies: [],
                installedOnRequest: graph.isRequested(node.name),
                installedAsDependency: !graph.isRequested(node.name), installedVersion: "1.0",
                isInstalled: true, installTime: nil, runtimeDependencies: [], isKegOnly: false
            )
        }
        stores.dependencies.structure = graph
        stores.dependencies.selectedNodeName = name
        return stores
    }
}
