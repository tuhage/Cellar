import Testing
import Foundation
@testable import CellarCore

@Suite("Cask Parsing")
struct CaskParsingTests {

    @Test("cask_decode_parsesTokenAndVersion")
    func cask_decode_parsesTokenAndVersion() throws {
        let data = try fixtureData("cask_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let cask = try #require(response.casks?.first)

        #expect(cask.token == "firefox")
        #expect(cask.fullToken == "firefox")
        #expect(cask.version == "147.0.2")
    }

    @Test("cask_decode_parsesInstalledVersion")
    func cask_decode_parsesInstalledVersion() throws {
        let data = try fixtureData("cask_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let cask = try #require(response.casks?.first)

        #expect(cask.installed == "147.0.2")
        #expect(cask.isInstalled == true)
    }

    @Test("cask_decode_parsesDisplayName")
    func cask_decode_parsesDisplayName() throws {
        let data = try fixtureData("cask_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let cask = try #require(response.casks?.first)

        #expect(cask.displayName == "Mozilla Firefox")
        #expect(cask.names == ["Mozilla Firefox"])
    }

    @Test("cask_decode_parsesFlags")
    func cask_decode_parsesFlags() throws {
        let data = try fixtureData("cask_installed.json")
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        let cask = try #require(response.casks?.first)

        #expect(cask.outdated == false)
        #expect(cask.autoUpdates == true)
        #expect(cask.deprecated == false)
        #expect(cask.disabled == false)
        #expect(cask.needsAttention == false)
    }

    @Test("cask_stub_isNotInstalled")
    func cask_stub_isNotInstalled() {
        let cask = Cask.stub(token: "visual-studio-code")

        #expect(cask.token == "visual-studio-code")
        #expect(cask.isInstalled == false)
        #expect(cask.installed == nil)
        #expect(cask.version == "unknown")
    }

    @Test("cask_preview_matchesExpectedValues")
    func cask_preview_matchesExpectedValues() {
        let cask = Cask.preview

        #expect(cask.token == "firefox")
        #expect(cask.isInstalled == true)
        #expect(cask.displayName == "Mozilla Firefox")
        #expect(cask.autoUpdates == true)
    }
}
