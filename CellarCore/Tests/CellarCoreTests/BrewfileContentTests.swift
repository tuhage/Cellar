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

        #expect(content.formulae.map(\.name) == ["postgresql@16"])
        #expect(content.casks.map(\.name) == ["visual-studio-code"])
        #expect(content.taps.map(\.name) == ["homebrew/services"])
    }

    @Test("tolerates an unterminated quoted entry")
    func toleratesUnterminatedQuote() {
        let content = BrewfileContent.parse(from: "brew \"wget")
        #expect(content.formulae.first?.name == "wget")
    }
}
