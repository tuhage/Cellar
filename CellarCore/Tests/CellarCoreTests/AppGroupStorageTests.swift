import Testing
@testable import CellarCore

@Suite("App Group Storage")
struct AppGroupStorageTests {
    @Test("uses a team-authorized macOS app group identifier")
    func usesTeamAuthorizedIdentifier() {
        #expect(AppGroupStorage.groupIdentifier == "23H73A78A7.com.tuhage.Cellar")
    }
}
