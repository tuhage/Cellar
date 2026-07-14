import Testing
@testable import CellarCore

@Suite("Semantic Version")
struct SemanticVersionTests {
    @Test("normalizes missing zero components")
    func normalizesCoreComponents() {
        #expect(SemanticVersion("1.2") == SemanticVersion("1.2.0"))
    }

    @Test("compares numeric components numerically")
    func comparesNumericComponents() {
        #expect(SemanticVersion("1.10.0") > SemanticVersion("1.2.0"))
    }

    @Test("release is newer than prerelease")
    func comparesPrerelease() {
        #expect(SemanticVersion("2.0.0") > SemanticVersion("2.0.0-beta.2"))
        #expect(SemanticVersion("2.0.0-beta.11") > SemanticVersion("2.0.0-beta.2"))
    }
}
