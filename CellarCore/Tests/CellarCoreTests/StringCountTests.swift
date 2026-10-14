import Foundation
import Testing
@testable import CellarCore

@Suite("String.count")
struct StringCountTests {

    /// Grammar agreement follows the current language.
    @Test("stringCount_agreesWithCount", .enabled(if: Locale.current.language.languageCode == .english))
    func stringCount_agreesWithCount() {
        #expect(String.count(1, "package") == "1 package")
        #expect(String.count(3, "package") == "3 packages")
        #expect(String.count(0, "item") == "0 items")
        #expect(String.count(2, "dependency") == "2 dependencies")
        #expect(String.count(2, "process") == "2 processes")
        #expect(String.count(2, "Package") == "2 Packages")
    }
}
