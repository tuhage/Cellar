import Foundation

// MARK: - DependencyNode

/// One installed package in the ``DependencyGraph``.
///
/// `dependencies` and `dependents` are complete — they include packages
/// reached through others — because `brew deps --installed` lists every
/// runtime dependency. The `direct` lists keep only the first step, which
/// is what an outline of "who needs whom" shows.
public struct DependencyNode: Identifiable, Hashable, Sendable {

    // MARK: Data

    public let name: String
    /// Everything it needs at runtime, directly or through other packages.
    public let dependencies: [String]
    /// Every installed package that needs it, directly or indirectly.
    public let dependents: [String]
    /// The dependencies it needs itself rather than through another one.
    public let directDependencies: [String]
    /// The installed packages that need it directly.
    public let directDependents: [String]

    public var id: String { name }

    // MARK: Init

    public init(
        name: String,
        dependencies: [String],
        dependents: [String],
        directDependencies: [String]? = nil,
        directDependents: [String]? = nil
    ) {
        self.name = name
        self.dependencies = dependencies
        self.dependents = dependents
        self.directDependencies = directDependencies ?? dependencies
        self.directDependents = directDependents ?? dependents
    }

    // MARK: Search

    /// The names that make the node match `query` in `scope` — its own name,
    /// or the dependencies or dependents containing the query. Empty when
    /// it doesn't match.
    public func matches(_ query: String, in scope: DependencySearchScope) -> [String] {
        let candidates = switch scope {
        case .name: [name]
        case .dependsOn: dependencies
        case .usedBy: dependents
        }
        return candidates.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    // MARK: Preview

    public static var preview: DependencyNode {
        DependencyGraph.preview.node(named: "openssl@3")!
    }
}

// MARK: - DependencySearchScope

/// What a search on the dependency page looks at.
public enum DependencySearchScope: String, CaseIterable, Sendable {
    /// The package's own name.
    case name
    /// Packages that need a package matching the query.
    case dependsOn
    /// Packages that a package matching the query needs.
    case usedBy
}

// MARK: - DependencyGraph

/// Which installed packages need which, and why each one is installed.
///
/// A package is either *requested* — the user installed it, like
/// `brew leaves --installed-on-request` — or a *dependency* Homebrew pulled
/// in. A dependency that no requested package needs anymore is *removable*:
/// exactly what `brew autoremove` would uninstall.
public struct DependencyGraph: Sendable {

    // MARK: Data

    /// Sorted by name.
    public let nodes: [DependencyNode]
    private let nodesByName: [String: DependencyNode]

    /// Formulae Homebrew installed only to satisfy another package. Every
    /// other package — casks included — counts as requested, so nothing
    /// Cellar knows too little about is ever offered for removal.
    public var dependencyInstalls: Set<String>

    // MARK: Init

    /// - Parameter dependencies: Each installed package with all of its
    ///   runtime dependencies, as parsed by ``parse(_:)``.
    public init(dependencies: [String: [String]], dependencyInstalls: Set<String> = []) {
        var allDependencies = dependencies.mapValues(Set.init)
        for name in dependencies.values.joined() where allDependencies[name] == nil {
            allDependencies[name] = []
        }

        let directDependencies = allDependencies.mapValues { deps in
            Self.direct(deps, allDependencies: allDependencies)
        }
        var dependents: [String: [String]] = [:]
        var directDependents: [String: [String]] = [:]
        for (package, deps) in allDependencies {
            for dependency in deps {
                dependents[dependency, default: []].append(package)
            }
            for dependency in directDependencies[package] ?? [] {
                directDependents[dependency, default: []].append(package)
            }
        }

        let nodes = allDependencies.keys.sorted().map { name in
            DependencyNode(
                name: name,
                dependencies: allDependencies[name, default: []].sorted(),
                dependents: dependents[name, default: []].sorted(),
                directDependencies: directDependencies[name, default: []].sorted(),
                directDependents: directDependents[name, default: []].sorted()
            )
        }
        self.nodes = nodes
        self.nodesByName = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
        self.dependencyInstalls = dependencyInstalls
    }

    /// Drops every dependency that another dependency already brings in,
    /// leaving the ones the package declares itself.
    private static func direct(_ deps: Set<String>, allDependencies: [String: Set<String>]) -> [String] {
        deps.filter { candidate in
            !deps.contains { other in
                other != candidate && allDependencies[other]?.contains(candidate) == true
            }
        }
    }

    // MARK: Parsing

    /// Parses `brew deps --installed`: one `package: dep dep…` line per
    /// installed package, `package:` alone when it has none.
    public static func parse(_ depsOutput: String) -> [String: [String]] {
        var dependencies: [String: [String]] = [:]
        for line in depsOutput.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let package = line[..<colon].trimmingCharacters(in: .whitespaces)
            guard !package.isEmpty else { continue }
            dependencies[package] = line[line.index(after: colon)...]
                .split(separator: " ")
                .map(String.init)
        }
        return dependencies
    }

    // MARK: Lookup

    public func node(named name: String) -> DependencyNode? {
        nodesByName[name]
    }

    // MARK: Install Reasons

    /// The user installed it rather than Homebrew pulling it in.
    public func isRequested(_ name: String) -> Bool {
        !dependencyInstalls.contains(name)
    }

    /// Installed as a dependency, and no package the user installed needs it
    /// anymore — not even through other dependencies.
    public func isRemovable(_ node: DependencyNode) -> Bool {
        !isRequested(node.name) && !node.dependents.contains(where: isRequested)
    }

    /// What `brew autoremove` would uninstall.
    public var removableNodes: [DependencyNode] {
        nodes.filter(isRemovable)
    }

    /// Dependencies that only `name` still needs: uninstalling it leaves
    /// them removable.
    public func dependenciesFreed(byRemoving name: String) -> [String] {
        guard let node = node(named: name) else { return [] }
        return node.dependencies.filter { dependency in
            guard let candidate = self.node(named: dependency), !isRequested(dependency) else { return false }
            return candidate.dependents.allSatisfy { $0 == name || !isRequested($0) }
                && !isRemovable(candidate)
        }
    }

    // MARK: Why Installed

    /// The packages that need `name`, each expanding to the packages that
    /// need it in turn, up to the ones the user installed.
    public func dependentChains(of name: String) -> [DependentChain] {
        DependentChain(name: name, path: [], graph: self).children ?? []
    }

    // MARK: Preview

    public static var preview: DependencyGraph {
        let output = """
        git: gettext pcre2
        node: ada-url brotli c-ares ca-certificates icu4c@78 libnghttp2 libuv openssl@3
        openssl@3: ca-certificates
        ca-certificates:
        wget: ca-certificates gettext libidn2 libunistring openssl@3
        libidn2: gettext libunistring
        gettext: libunistring
        python@3.12: ca-certificates mpdecimal openssl@3 readline sqlite xz
        """
        return DependencyGraph(
            dependencies: parse(output),
            dependencyInstalls: [
                "ada-url", "brotli", "c-ares", "ca-certificates", "gettext", "icu4c@78",
                "libidn2", "libnghttp2", "libunistring", "libuv", "mpdecimal", "openssl@3",
                "pcre2", "python@3.12", "readline", "sqlite", "xz",
            ]
        )
    }
}

// MARK: - DependentChain

/// One step in the answer to "why is this installed?": a package that
/// needs the one above it. Its `children` — the packages that need it —
/// are computed only when an outline expands it.
public struct DependentChain: Identifiable, Sendable {
    public let name: String
    /// The packages between this one and the package being explained.
    private let path: [String]
    private let graph: DependencyGraph

    fileprivate init(name: String, path: [String], graph: DependencyGraph) {
        self.name = name
        self.path = path
        self.graph = graph
    }

    /// Unique within the outline; the same package can appear on several chains.
    public var id: String { (path + [name]).joined(separator: "/") }

    /// The chain ends here: the user installed this package.
    public var isRequested: Bool { graph.isRequested(name) }

    /// `nil` where the chain ends — at a requested package, or at a
    /// dependency nothing needs anymore.
    public var children: [DependentChain]? {
        guard !isRequested || path.isEmpty, let node = graph.node(named: name) else { return nil }
        let chains = node.directDependents
            .filter { !path.contains($0) }
            .map { DependentChain(name: $0, path: path + [name], graph: graph) }
        return chains.isEmpty ? nil : chains
    }
}
