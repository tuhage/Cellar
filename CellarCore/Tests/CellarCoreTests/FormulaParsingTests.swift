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
