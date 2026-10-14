import Testing
import Foundation
@testable import CellarCore

@Suite("Formula Parsing")
struct FormulaParsingTests {

    @Test("formula_decode_parsesNameAndVersion")
    func formula_decode_parsesNameAndVersion() throws {
        let data = try fixtureData("formula_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let formula = try #require(response.formulae.first)

        #expect(formula.name == "openssl@3")
        #expect(formula.fullName == "openssl@3")
        #expect(formula.version == "3.6.0")
        #expect(formula.installedVersion == "3.6.0")
        #expect(formula.latestVersion == "3.6.0")
    }

    @Test("formula_decode_withSeveralKegs_usesLinkedKeg")
    func formula_decode_withSeveralKegs_usesLinkedKeg() throws {
        let formula = try JSONDecoder().decode(Formula.self, from: Data(Self.multiKegJSON(linkedKeg: "\"17.11_1\"").utf8))

        #expect(formula.version == "17.11_1")
        #expect(formula.installTime == Date(timeIntervalSince1970: 1_791_918_049))
    }

    @Test("formula_decode_withSeveralKegsAndNoLinkedKeg_usesNewestKeg")
    func formula_decode_withSeveralKegsAndNoLinkedKeg_usesNewestKeg() throws {
        let formula = try JSONDecoder().decode(Formula.self, from: Data(Self.multiKegJSON(linkedKeg: "null").utf8))

        #expect(formula.version == "17.11_1")
    }

    @Test("formula_decode_withRevision_targetsRevisedVersion")
    func formula_decode_withRevision_targetsRevisedVersion() throws {
        let json = """
        {
          "name": "ada-url",
          "full_name": "ada-url",
          "versions": { "stable": "4.0.0" },
          "revision": 1,
          "outdated": true,
          "linked_keg": "4.0.0",
          "installed": [{ "version": "4.0.0" }]
        }
        """
        let formula = try JSONDecoder().decode(Formula.self, from: Data(json.utf8))

        #expect(formula.version == "4.0.0")
        #expect(formula.latestVersion == "4.0.0_1")
    }

    /// brew lists old kegs first when `brew cleanup` hasn't removed them.
    private static func multiKegJSON(linkedKeg: String) -> String {
        """
        {
          "name": "postgresql@17",
          "full_name": "postgresql@17",
          "versions": { "stable": "17.11" },
          "linked_keg": \(linkedKeg),
          "installed": [
            { "version": "17.10", "time": 1785356324 },
            { "version": "17.11_1", "time": 1791918049 }
          ]
        }
        """
    }

    @Test("formula_decode_parsesInstalledFields")
    func formula_decode_parsesInstalledFields() throws {
        let data = try fixtureData("formula_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let formula = try #require(response.formulae.first)

        #expect(formula.isInstalled == true)
        #expect(formula.installedAsDependency == true)
        #expect(formula.installedOnRequest == false)
    }

    @Test("formula_decode_parsesInstallTime")
    func formula_decode_parsesInstallTime() throws {
        let data = try fixtureData("formula_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let formula = try #require(response.formulae.first)

        let expectedDate = Date(timeIntervalSince1970: 1_768_746_915)
        #expect(formula.installTime == expectedDate)
    }

    @Test("formula_decode_parsesRuntimeDependencies")
    func formula_decode_parsesRuntimeDependencies() throws {
        let data = try fixtureData("formula_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let formula = try #require(response.formulae.first)

        #expect(formula.runtimeDependencies.count == 1)
        #expect(formula.runtimeDependencies.first?.fullName == "ca-certificates")
        #expect(formula.runtimeDependencies.first?.version == "2025-12-02")
    }

    @Test("formula_needsAttention_trueWhenOutdated")
    func formula_needsAttention_trueWhenOutdated() throws {
        let data = try fixtureData("formula_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let formula = try #require(response.formulae.first)

        #expect(formula.outdated == true)
        #expect(formula.needsAttention == true)
    }

    @Test("formula_decode_parsesCaveatsAndRoundTrips")
    func formula_decode_parsesCaveatsAndRoundTrips() throws {
        let json = """
        { "name": "node", "full_name": "node", "versions": { "stable": "25.0.0" },
          "caveats": "Single Executable Application is disabled.",
          "installed": [{ "version": "25.0.0", "time": 1791918049 }] }
        """
        let formula = try JSONDecoder().decode(Formula.self, from: Data(json.utf8))
        let decoded = try JSONDecoder().decode(Formula.self, from: JSONEncoder().encode(formula))

        #expect(formula.caveats == "Single Executable Application is disabled.")
        #expect(decoded == formula)
    }

    @Test("formula_dependents_findsInstalledFormulaeNeedingIt")
    func formula_dependents_findsInstalledFormulaeNeedingIt() {
        let openssl = Formula.stub(name: "openssl@3")
        let curl = Self.formula("curl", runtimeDependencies: ["openssl@3", "libssh2"])
        let wget = Self.formula("wget", runtimeDependencies: ["openssl@3"])
        let jq = Self.formula("jq", runtimeDependencies: ["oniguruma"])

        #expect(openssl.dependents(in: [curl, wget, jq]).map(\.name) == ["curl", "wget"])
        #expect(jq.dependents(in: [curl, wget, jq]).isEmpty)
    }

    @Test("formula_installCommandAndKeg_useFullNameAndInstalledVersion")
    func formula_installCommandAndKeg_useFullNameAndInstalledVersion() throws {
        let formula = Formula.preview

        #expect(formula.installCommand == "brew install openssl@3")
        let keg = try #require(formula.kegURL)
        #expect(keg.path().hasSuffix("/Cellar/openssl@3/3.6.0/"))
        #expect(Formula.stub(name: "wget").kegURL == nil)
    }

    @Test("searchResultOrdering_keepsBrewOrderAndStubsUndescribedNames")
    func searchResultOrdering_keepsBrewOrderAndStubsUndescribedNames() {
        let details = [Self.formula("wget2"), Self.formula("wget")]

        let results = SearchResultOrdering.ordered(
            ["wget", "someone/tap/wgetpaste", "wget2"],
            details: details,
            keys: { [$0.name, $0.fullName] },
            stub: Formula.stub(name:)
        )

        #expect(results.map(\.name) == ["wget", "someone/tap/wgetpaste", "wget2"])
        #expect(results.map(\.isInstalled) == [true, false, true])
    }

    private static func formula(_ name: String, runtimeDependencies: [String] = []) -> Formula {
        Formula(
            name: name, fullName: name, desc: nil, license: nil, homepage: nil, version: "1.0",
            deprecated: false, disabled: false, outdated: false, pinned: false,
            dependencies: runtimeDependencies, buildDependencies: [],
            installedOnRequest: true, installedAsDependency: false, installedVersion: "1.0",
            isInstalled: true, installTime: nil,
            runtimeDependencies: runtimeDependencies.map { RuntimeDependency(fullName: $0, version: "1.0") },
            isKegOnly: false
        )
    }

    @Test("formula_stub_isNotInstalled")
    func formula_stub_isNotInstalled() {
        let formula = Formula.stub(name: "wget")

        #expect(formula.name == "wget")
        #expect(formula.isInstalled == false)
        #expect(formula.installedVersion == nil)
        #expect(formula.version == "unknown")
    }

    @Test("formula_preview_matchesExpectedValues")
    func formula_preview_matchesExpectedValues() {
        let formula = Formula.preview

        #expect(formula.name == "openssl@3")
        #expect(formula.isInstalled == true)
        #expect(formula.outdated == true)
        #expect(formula.installedAsDependency == true)
    }
}
