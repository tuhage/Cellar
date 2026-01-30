import Foundation

// MARK: - DependencyNode

/// Represents a single package in the dependency graph.
///
/// Each node knows both its dependencies (packages it requires) and its
/// dependents (packages that require it). Constructed by ``DependencyGraph/build(from:)``.
struct DependencyNode: Identifiable, Hashable, Sendable {

    // MARK: Data

    let name: String
    let dependencies: [String]
    let dependents: [String]

    var id: String { name }

    // MARK: Computed

    /// A leaf node has no dependencies of its own.
    var isLeaf: Bool { dependencies.isEmpty }

    /// An orphan node is installed but nothing depends on it,
    /// and it is not a leaf (i.e. it has its own dependencies).
    var isOrphan: Bool { dependents.isEmpty && !isLeaf }

    /// The total number of direct connections (dependencies + dependents).
    var connectionCount: Int { dependencies.count + dependents.count }

    // MARK: Preview

    static var preview: DependencyNode {
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
struct DependencyGraph: Sendable {

    // MARK: Data

    let nodes: [DependencyNode]
    let edges: [(from: String, to: String)]

    // MARK: Computed

    /// Packages that nothing else depends on (and are not leaves).
    var orphans: [DependencyNode] {
        nodes.filter(\.isOrphan)
    }

    /// Packages with no dependencies of their own.
    var leaves: [DependencyNode] {
        nodes.filter(\.isLeaf)
    }

    /// Total number of unique packages in the graph.
    var totalPackages: Int { nodes.count }

    /// Total number of dependency edges.
    var totalEdges: Int { edges.count }

    /// The node with the most dependents.
    var mostDepended: DependencyNode? {
        nodes.max(by: { $0.dependents.count < $1.dependents.count })
    }

    /// Look up a node by name.
    func node(named name: String) -> DependencyNode? {
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
    static func build(from depsOutput: String) -> DependencyGraph {
        // Parse each line into (package, [dependency])
        var dependencyMap: [String: [String]] = [:]

        let lines = depsOutput.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let package = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            guard !package.isEmpty else { continue }

            let depsString = line[line.index(after: colonIndex)...]
            let deps = depsString
                .split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)

            dependencyMap[package] = deps

            // Ensure every dependency also has an entry (some may have no line of their own)
            for dep in deps {
                if dependencyMap[dep] == nil {
                    dependencyMap[dep] = []
                }
            }
        }

        // Build reverse map: who depends on each package
        var dependentsMap: [String: [String]] = [:]
        for (package, deps) in dependencyMap {
            for dep in deps {
                dependentsMap[dep, default: []].append(package)
            }
        }

        // Build edges
        var edges: [(from: String, to: String)] = []
        for (package, deps) in dependencyMap {
            for dep in deps {
                edges.append((from: package, to: dep))
            }
        }

        // Build nodes
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

    static var preview: DependencyGraph {
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

// MARK: - Hashable Conformance for Edge Tuples

/// Since tuples aren't Hashable, we don't make DependencyGraph Hashable.
/// Nodes carry all the relationship data needed by views.
