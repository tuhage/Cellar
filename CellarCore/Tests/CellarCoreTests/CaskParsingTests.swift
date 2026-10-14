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

    @Test("cask_decode_readsAppPathFromArtifactTarget")
    func cask_decode_readsAppPathFromArtifactTarget() throws {
        let casks = try Self.artifactCasks()

        #expect(casks[0].appPaths == ["/Applications/Firefox.app"])
        #expect(casks[0].appURL == URL(fileURLWithPath: "/Applications/Firefox.app"))
    }

    @Test("cask_decode_withoutTarget_assumesApplicationsFolder")
    func cask_decode_withoutTarget_assumesApplicationsFolder() throws {
        let casks = try Self.artifactCasks()

        #expect(casks[1].appPaths == ["/Applications/Legacy.app"])
        #expect(casks[2].appPaths.isEmpty)
        #expect(casks[2].appURL == nil)
    }

    @Test("cask_decode_readsZapPathsWithoutRmdir")
    func cask_decode_readsZapPathsWithoutRmdir() throws {
        let casks = try Self.artifactCasks()

        #expect(casks[0].zapPaths == ["~/Library/Application Support/Firefox", "~/Library/Caches/Firefox"])
        #expect(casks[1].zapPaths == ["~/Library/Preferences/com.example.legacy.plist", "/Library/Legacy"])
        #expect(casks[2].zapPaths.isEmpty)
    }

    @Test("cask_decode_parsesCaveats")
    func cask_decode_parsesCaveats() throws {
        let casks = try Self.artifactCasks()

        #expect(casks[0].caveats == nil)
        #expect(casks[1].caveats == "Legacy requires a restart after installing.\n")
    }

    @Test("cask_encode_roundTripsArtifactPathsAndCaveats")
    func cask_encode_roundTripsArtifactPathsAndCaveats() throws {
        let original = try Self.artifactCasks()[1]

        let decoded = try JSONDecoder().decode(Cask.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
    }

    @Test("cask_installCommand_usesQualifiedToken")
    func cask_installCommand_usesQualifiedToken() throws {
        let casks = try Self.artifactCasks()

        #expect(casks[1].installCommand == "brew install --cask someone/tap/legacy-app")
        #expect(Cask.stub(token: "zed").installCommand == "brew install --cask zed")
    }

    private static func artifactCasks() throws -> [Cask] {
        let data = try fixtureData("cask_artifacts.json")
        return try JSONDecoder().decode(BrewJSONResponse.self, from: data).casks ?? []
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
