import Testing
@testable import CellarCore

@Suite("Brewfile Content")
struct BrewfileContentTests {

    @Test("parses entries with trailing options without crashing")
    func parsesEntriesWithOptions() {
        let content = BrewfileContent.parse(from: """
        brew "postgresql@16", restart_service: true
        cask 'visual-studio-code', greedy: true
        tap "homebrew/services"
        """)

        #expect(content.entries(of: .brew).map(\.name) == ["postgresql@16"])
        #expect(content.entries(of: .cask).map(\.name) == ["visual-studio-code"])
        #expect(content.entries(of: .tap).map(\.name) == ["homebrew/services"])
    }

    @Test("tolerates an unterminated quoted entry")
    func toleratesUnterminatedQuote() {
        let content = BrewfileContent.parse(from: "brew \"wget")
        #expect(content.entries(of: .brew).first?.name == "wget")
    }

    @Test("brewfileContent_parse_keepsOtherPackageManagersInsteadOfDroppingThem")
    func brewfileContent_parse_keepsOtherPackageManagersInsteadOfDroppingThem() {
        let content = BrewfileContent.parse(from: """
        mas "Final Cut Pro", id: 424389933
        vscode "ms-python.python"
        go "github.com/swaggo/swag/cmd/swag"
        cargo "cargo-ndk"
        whalebrew "whalebrew/wget"
        npm "@expo/ngrok"
        """)

        #expect(content.entries.map(\.kind) == [.mas, .vscode, .go, .cargo, .whalebrew, .other])
        #expect(content.entries(of: .mas).first?.name == "Final Cut Pro")
        #expect(content.entries(of: .other).first?.keyword == "npm")
        #expect(content.entries(of: .other).first?.id == "npm:@expo/ngrok")
    }

    @Test("brewfileContent_parse_skipsCommentsOptionsAndRubyCode")
    func brewfileContent_parse_skipsCommentsOptionsAndRubyCode() {
        let content = BrewfileContent.parse(from: """
        # Command-line tools
        cask_args appdir: "~/Applications"
        if OS.mac?
          brew "wget" # downloads
        end
        """)

        #expect(content.entries.map(\.id) == ["brew:wget"])
    }

    @Test("brewfileContent_entryIDs_distinguishSameNameAcrossKinds")
    func brewfileContent_entryIDs_distinguishSameNameAcrossKinds() {
        let content = BrewfileContent.parse(from: "brew \"docker\"\ncask \"docker\"")
        #expect(Set(content.entries.map(\.id)).count == 2)
    }

    @Test("brewfileContent_appending_keepsExistingTextAndAddsNewline")
    func brewfileContent_appending_keepsExistingTextAndAddsNewline() {
        let text = "# My setup\nbrew \"wget\""

        let result = BrewfileContent.appending(["brew \"jq\""], to: text)

        #expect(result == "# My setup\nbrew \"wget\"\nbrew \"jq\"\n")
        #expect(BrewfileContent.appending([], to: text) == text)
    }

    @Test("brewfileContent_removing_dropsOnlyTheMatchingEntryLine")
    func brewfileContent_removing_dropsOnlyTheMatchingEntryLine() {
        let text = "# Tools\nbrew \"wget\"\ncask \"wget\"\nbrew \"jq\"\n"
        let entry = BrewfileContent.Entry(keyword: "brew", name: "wget")

        #expect(BrewfileContent.removing(entry, from: text) == "# Tools\ncask \"wget\"\nbrew \"jq\"\n")
    }

    @Test("brewfileContentEntry_matches_acceptsTapQualifiedNames")
    func brewfileContentEntry_matches_acceptsTapQualifiedNames() {
        let maestro = Formula(
            name: "maestro", fullName: "mobile-dev-inc/tap/maestro", desc: nil, license: nil, homepage: nil,
            version: "2.0", deprecated: false, disabled: false, outdated: true, pinned: false,
            dependencies: [], buildDependencies: [], installedOnRequest: true, installedAsDependency: false,
            installedVersion: "2.0", isInstalled: true, installTime: nil, runtimeDependencies: [], isKegOnly: false
        )

        #expect(BrewfileContent.Entry(keyword: "brew", name: "maestro").matches(maestro))
        #expect(BrewfileContent.Entry(keyword: "brew", name: "mobile-dev-inc/tap/maestro").matches(maestro))
        #expect(!BrewfileContent.Entry(keyword: "cask", name: "maestro").matches(maestro))
        #expect(BrewfileContent.Entry(keyword: "cask", name: "firefox").matches(Cask.preview))
    }
}
