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
