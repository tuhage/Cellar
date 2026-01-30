import Foundation

// MARK: - DependencyNode

/// Represents a single package in the dependency graph.
///
/// Each node knows both its dependencies (packages it requires) and its
/// dependents (packages that require it). Constructed by ``DependencyGraph/build(from:)``.
public struct DependencyNode: Identifiable, Hashable, Sendable {

    // MARK: Data

    public let name: String
    public let dependencies: [String]
    public let dependents: [String]

    public var id: String { name }

    // MARK: Init

    public init(name: String, dependencies: [String], dependents: [String]) {
        self.name = name
        self.dependencies = dependencies
        self.dependents = dependents
    }

    // MARK: Computed

    /// A leaf node has no dependencies of its own.
    public var isLeaf: Bool { dependencies.isEmpty }

    /// An orphan node is installed but nothing depends on it,
    /// and it is not a leaf (i.e. it has its own dependencies).
    public var isOrphan: Bool { dependents.isEmpty && !isLeaf }

    /// The total number of direct connections (dependencies + dependents).
    public var connectionCount: Int { dependencies.count + dependents.count }

    // MARK: Preview

    public static var preview: DependencyNode {
        DependencyNode(
            name: "openssl@3",
            dependencies: ["ca-certificates"],
            dependents: ["node", "python@3.12", "wget"]
        )
    }
}

// MARK: - DependencyGraph

/// The full dependency graph built from `brew deps --installed` output.
///
/// Each line of the output has the format `package: dep1 dep2 dep3`.
/// Packages with no dependencies appear as `package:` (no trailing names).
public struct DependencyGraph: Sendable {

    // MARK: Data

    public let nodes: [DependencyNode]
    public let edges: [(from: String, to: String)]

    // MARK: Init

    public init(nodes: [DependencyNode], edges: [(from: String, to: String)]) {
        self.nodes = nodes
        self.edges = edges
    }

    // MARK: Computed

    /// Packages that nothing else depends on (and are not leaves).
    public var orphans: [DependencyNode] {
        nodes.filter(\.isOrphan)
    }

    /// Packages with no dependencies of their own.
    public var leaves: [DependencyNode] {
        nodes.filter(\.isLeaf)
    }

    /// Total number of unique packages in the graph.
    public var totalPackages: Int { nodes.count }

    /// Total number of dependency edges.
    public var totalEdges: Int { edges.count }

    /// The node with the most dependents.
    public var mostDepended: DependencyNode? {
        nodes.max(by: { $0.dependents.count < $1.dependents.count })
    }

    /// Look up a node by name.
    public func node(named name: String) -> DependencyNode? {
        nodes.first(where: { $0.name == name })
    }

    // MARK: Factory

    /// Builds a ``DependencyGraph`` from the output of `brew deps --installed`.
    ///
    /// Expected format — one line per installed package:
    /// ```
    /// git: gettext pcre2
    /// node: ada-url brotli c-ares icu4c@78 libnghttp2 libuv openssl@3
    /// openssl@3: ca-certificates
    /// ca-certificates:
    /// ```
    public static func build(from depsOutput: String) -> DependencyGraph {
        var dependencyMap: [String: [String]] = [:]

        for line in depsOutput.split(separator: "\n") {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let package = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            guard !package.isEmpty else { continue }

            let deps = line[line.index(after: colonIndex)...]
                .split(separator: " ")
                .map(String.init)

            dependencyMap[package] = deps

            for dep in deps where dependencyMap[dep] == nil {
                dependencyMap[dep] = []
            }
        }

        // Build reverse map and edges in a single pass
        var dependentsMap: [String: [String]] = [:]
        var edges: [(from: String, to: String)] = []

        for (package, deps) in dependencyMap {
            for dep in deps {
                dependentsMap[dep, default: []].append(package)
                edges.append((from: package, to: dep))
            }
        }

        let nodes = dependencyMap.keys.sorted().map { name in
            DependencyNode(
                name: name,
                dependencies: (dependencyMap[name] ?? []).sorted(),
                dependents: (dependentsMap[name] ?? []).sorted()
            )
        }

        return DependencyGraph(nodes: nodes, edges: edges)
    }

    // MARK: Preview

    public static var preview: DependencyGraph {
        let output = """
        git: gettext pcre2
        node: ada-url brotli c-ares icu4c@78 libnghttp2 libuv openssl@3
        openssl@3: ca-certificates
        ca-certificates:
        wget: gettext libidn2 libunistring openssl@3
        python@3.12: mpdecimal openssl@3 readline sqlite xz
        """
        return DependencyGraph.build(from: output)
    }
}
