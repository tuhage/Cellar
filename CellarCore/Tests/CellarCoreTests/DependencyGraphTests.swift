import Testing
import Foundation
@testable import CellarCore

@Suite("Dependency Graph")
struct DependencyGraphTests {

    /// gh, wget and the firefox cask were installed by the user; cairo was
    /// pulled in by a package since uninstalled, libnghttp3/libngtcp2 too.
    private static let dependencyInstalls: Set<String> = [
        "ca-certificates", "cairo", "fontconfig", "freetype", "gettext", "glib", "libidn2",
        "libnghttp3", "libngtcp2", "libpng", "libunistring", "openssl@3", "pcre2",
    ]

    private func makeGraph() throws -> DependencyGraph {
        let output = try #require(String(data: fixtureData("deps_installed.txt"), encoding: .utf8))
        return DependencyGraph(dependencies: DependencyGraph.parse(output), dependencyInstalls: Self.dependencyInstalls)
    }

    @Test
    func dependencyGraph_parse_readsEveryPackageLine() throws {
        let graph = try makeGraph()

        #expect(graph.nodes.count == 16)
        #expect(graph.node(named: "gh")?.dependencies.isEmpty == true)
        #expect(graph.node(named: "freetype")?.dependencies == ["libpng"])
    }

    @Test
    func dependencyGraph_init_keepsOnlyDirectDependencies() throws {
        let graph = try makeGraph()

        #expect(graph.node(named: "cairo")?.directDependencies == ["fontconfig", "glib"])
        #expect(graph.node(named: "wget")?.directDependencies == ["libidn2", "openssl@3"])
        #expect(graph.node(named: "gettext")?.directDependents == ["fontconfig", "glib", "libidn2"])
    }

    @Test
    func dependencyGraph_init_listsIndirectDependents() throws {
        let graph = try makeGraph()

        #expect(graph.node(named: "libpng")?.dependents == ["cairo", "fontconfig", "freetype"])
    }

    @Test
    func dependencyGraph_isRequested_treatsUnknownPackagesAsRequested() throws {
        let graph = try makeGraph()

        #expect(graph.isRequested("wget"))
        #expect(graph.isRequested("firefox"))
        #expect(!graph.isRequested("openssl@3"))
        #expect(graph.requestedNodes.map(\.name) == ["firefox", "gh", "wget"])
    }

    @Test
    func dependencyGraph_removableNodes_matchesAutoremove() throws {
        let graph = try makeGraph()

        #expect(graph.removableNodes.map(\.name) == [
            "cairo", "fontconfig", "freetype", "glib", "libnghttp3", "libngtcp2", "libpng", "pcre2",
        ])
    }

    @Test
    func dependencyGraph_removableNodes_isEmptyWithoutInstallReasons() throws {
        var graph = try makeGraph()
        graph.dependencyInstalls = []

        #expect(graph.removableNodes.isEmpty)
    }

    @Test
    func dependencyGraph_dependenciesFreed_listsDependenciesOnlyThePackageNeeds() throws {
        let graph = try makeGraph()

        #expect(graph.dependenciesFreed(byRemoving: "wget") == [
            "ca-certificates", "gettext", "libidn2", "libunistring", "openssl@3",
        ])
        #expect(graph.dependenciesFreed(byRemoving: "gh").isEmpty)
    }

    @Test
    func dependencyGraph_dependentChains_endAtRequestedPackages() throws {
        let graph = try makeGraph()
        let chains = graph.dependentChains(of: "gettext")

        #expect(chains.map(\.name) == ["fontconfig", "glib", "libidn2"])
        let wget = try #require(chains.last?.children?.first)
        #expect(wget.name == "wget")
        #expect(wget.isRequested)
        #expect(wget.children == nil)
        #expect(wget.id == "gettext/libidn2/wget")
    }

    @Test
    func dependencyGraph_dependentChains_expandsRequestedRoot() throws {
        let graph = try makeGraph()

        #expect(graph.dependentChains(of: "openssl@3").map(\.name) == ["libngtcp2", "wget"])
        #expect(graph.dependentChains(of: "gh").isEmpty)
    }

    @Test
    func dependencyNode_matches_reportsWhatMatched() throws {
        let graph = try makeGraph()
        let wget = try #require(graph.node(named: "wget"))
        let openssl = try #require(graph.node(named: "openssl@3"))

        #expect(wget.matches("WG", in: .name) == ["wget"])
        #expect(wget.matches("ssl", in: .dependsOn) == ["openssl@3"])
        #expect(openssl.matches("wget", in: .usedBy) == ["wget"])
        #expect(openssl.matches("wget", in: .dependsOn).isEmpty)
    }
}
