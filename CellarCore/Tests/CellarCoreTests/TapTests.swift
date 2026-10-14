import Testing
import Foundation
@testable import CellarCore

@Suite("Taps")
struct TapTests {

    private func loadTaps() throws -> [Tap] {
        try JSONDecoder().decode([Tap].self, from: fixtureData("tap_info.json"))
    }

    private func formula(_ name: String, fullName: String? = nil) -> Formula {
        Formula(
            name: name, fullName: fullName ?? name, desc: nil, license: nil, homepage: nil,
            version: "1.0", deprecated: false, disabled: false, outdated: false, pinned: false,
            dependencies: [], buildDependencies: [], installedOnRequest: true,
            installedAsDependency: false, installedVersion: "1.0", isInstalled: true,
            installTime: nil, runtimeDependencies: [], isKegOnly: false
        )
    }

    private func cask(_ token: String) -> Cask {
        Cask(
            token: token, fullToken: token, names: [token], desc: nil, homepage: nil,
            version: "1.0", installed: "1.0", outdated: false, autoUpdates: false,
            deprecated: false, disabled: false
        )
    }

    // MARK: Decoding

    @Test
    func tap_decode_toleratesNullsForAPITaps() throws {
        let taps = try loadTaps()

        #expect(taps.map(\.name) == ["homebrew/cask", "homebrew/core", "mobile-dev-inc/tap"])
        #expect(taps[1].remote.isEmpty)
        #expect(taps[2].branch == "master")
        #expect(taps[2].formulaCount == 3)
    }

    // MARK: Packages

    @Test
    func tap_tapName_readsQualifiedNamesAndDefaultsToCore() {
        #expect(Tap.tapName(ofPackage: "mobile-dev-inc/tap/maestro", isCask: false) == "mobile-dev-inc/tap")
        #expect(Tap.tapName(ofPackage: "wget", isCask: false) == "homebrew/core")
        #expect(Tap.tapName(ofPackage: "firefox", isCask: true) == "homebrew/cask")
    }

    @Test
    func tapUsage_usages_matchesInstalledPackagesToTheirTap() throws {
        let usages = TapUsage.usages(
            of: try loadTaps(),
            formulae: [formula("wget"), formula("maestro", fullName: "mobile-dev-inc/tap/maestro")],
            casks: [cask("firefox")]
        )

        #expect(usages.map(\.installedCount) == [1, 1, 1])
        #expect(usages[0].installedCasks == ["firefox"])
        #expect(usages[1].installedFormulae == ["wget"])
        #expect(usages[2].installedFormulae == ["maestro"])
    }

    @Test
    func tapUsage_availableFormulae_excludesInstalledAndStripsPrefix() throws {
        let taps = try loadTaps()
        let usage = TapUsage(tap: taps[2], installedFormulae: ["maestro"], installedCasks: [])

        #expect(usage.availableFormulae == ["ips2crash", "maestro-head"])
        #expect(usage.availableCasks.isEmpty)
    }

    // MARK: Last Commit

    @Test
    func tap_age_parsesGitRelativeDates() {
        let week: TimeInterval = 604_800
        let month: TimeInterval = 2_592_000
        let year: TimeInterval = 31_536_000

        #expect(Tap.age(fromRelativeDate: "2 weeks ago") == 2 * week)
        #expect(Tap.age(fromRelativeDate: "1 year, 2 months ago") == year + 2 * month)
        #expect(Tap.age(fromRelativeDate: "") == nil)
    }

    @Test
    func tap_lastCommitAge_sortsUnknownLast() throws {
        let taps = try loadTaps()

        #expect(taps[1].lastCommitAge == .infinity)
        #expect(taps[2].lastCommitAge < taps[1].lastCommitAge)
    }

    // MARK: Tap Names

    @Test
    func tapName_init_acceptsUserRepoAndStripsHomebrewPrefix() throws {
        let name = try #require(TapName(" Mobile-Dev-Inc/homebrew-tap "))

        #expect(name.name == "mobile-dev-inc/tap")
        #expect(name.defaultRemote.absoluteString == "https://github.com/mobile-dev-inc/homebrew-tap")
        #expect(!name.isOfficial)
        #expect(TapName("homebrew/cask-versions")?.isOfficial == true)
    }

    @Test(arguments: ["", "user", "user/", "/repo", "a/b/c", "us er/repo", "user/re.po", "user/homebrew-"])
    func tapName_init_rejectsInvalidNames(_ text: String) {
        #expect(TapName(text) == nil)
    }

    @Test
    func tapName_isValidRemote_acceptsGitURLs() {
        #expect(TapName.isValidRemote("https://gitlab.com/user/homebrew-tools.git"))
        #expect(TapName.isValidRemote("git@github.com:user/homebrew-tools.git"))
        #expect(TapName.isValidRemote("file:///Users/me/taps/tools"))
        #expect(!TapName.isValidRemote("not a url"))
        #expect(!TapName.isValidRemote("github.com/user/repo"))
        #expect(!TapName.isValidRemote(""))
    }
}
