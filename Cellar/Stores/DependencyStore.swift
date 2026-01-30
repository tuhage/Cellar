import Foundation
import Observation

// MARK: - DependencyStore

/// Manages the state for the dependency graph feature.
///
/// Coordinates loading the full dependency graph from `brew deps --installed`,
/// filtering, node selection, and detail lookups. Views bind to this store
/// for the dependency graph UI.
@Observable
@MainActor
final class DependencyStore {

    // MARK: Data

    var graph: DependencyGraph?

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var selectedNodeName: String?
    var showOrphansOnly = false

    // MARK: Dependencies

    private let service: BrewService

    init(service: BrewService = BrewService()) {
        self.service = service
    }

    // MARK: Computed

    /// All nodes from the graph, filtered by search query and orphan toggle.
    var filteredNodes: [DependencyNode] {
        guard let graph else { return [] }
        var result = graph.nodes

        if showOrphansOnly {
            result = result.filter(\.isOrphan)
        }

        guard !searchQuery.isEmpty else { return result }
        let query = searchQuery.localizedLowercase
        return result.filter { node in
            node.name.localizedCaseInsensitiveContains(query)
                || node.dependencies.contains(where: { $0.localizedCaseInsensitiveContains(query) })
                || node.dependents.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    /// The currently selected node, if any.
    var selectedNode: DependencyNode? {
        guard let name = selectedNodeName else { return nil }
        return graph?.node(named: name)
    }

    // MARK: Actions

    /// Loads the full dependency graph from Homebrew.
    func loadGraph() async {
        isLoading = true
        errorMessage = nil
        do {
            let output = try await service.depsInstalled()
            graph = DependencyGraph.build(from: output)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Looks up a specific node by name.
    func nodeDetails(_ name: String) -> DependencyNode? {
        graph?.node(named: name)
    }

    /// Selects a node by name, navigating to its detail.
    func select(_ name: String) {
        selectedNodeName = name
    }
}
