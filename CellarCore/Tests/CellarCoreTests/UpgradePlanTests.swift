import Foundation
import Testing
@testable import CellarCore

@Suite("Upgrade Plan")
struct UpgradePlanTests {

    private static let formulaOutput = """
    ==> Would upgrade 1 dependency:
    gradle-completion 9.6.1 -> 9.8.0 (17.3KB)
    ==> Would upgrade 3 requested outdated packages
    openjdk@17                  17.0.20 -> 17.0.20.1 (186.4MB)
    gradle                      9.7.0   -> 9.8.1 (157.7MB)
    mobile-dev-inc/tap/maestro  2.10.0  -> 2.11.0
    """

    @Test("upgradePlan_parse_readsVersionsAndSizes")
    func upgradePlan_parse_readsVersionsAndSizes() throws {
        let items = UpgradePlan.parse(
            Self.formulaOutput,
            requested: ["openjdk@17", "gradle", "mobile-dev-inc/tap/maestro"],
            isCask: false
        )

        #expect(items.map(\.name) == ["gradle-completion", "openjdk@17", "gradle", "mobile-dev-inc/tap/maestro"])
        let gradle = try #require(items.first { $0.name == "gradle" })
        #expect(gradle.currentVersion == "9.7.0")
        #expect(gradle.targetVersion == "9.8.1")
        #expect(gradle.downloadBytes == 157_700_000)
        #expect(items.last?.downloadBytes == nil)
        #expect(items.last?.shortName == "maestro")
    }

    @Test("upgradePlan_parse_marksPackagesBrewPullsIn")
    func upgradePlan_parse_marksPackagesBrewPullsIn() {
        let plan = UpgradePlan(items: UpgradePlan.parse(
            Self.formulaOutput,
            requested: ["openjdk@17", "gradle", "maestro"],
            isCask: false
        ))

        #expect(plan.additionalItems.map(\.name) == ["gradle-completion"])
        #expect(plan.totalDownloadBytes == 186_400_000 + 157_700_000 + 17_300)
    }

    @Test("upgradePlan_parse_ignoresWarningsAndDuplicates")
    func upgradePlan_parse_ignoresWarningsAndDuplicates() {
        let output = """
        Warning: Not upgrading android-commandlinetools, the latest version is already installed
        firefox 1.0 -> 2.0
        firefox 1.0 -> 2.0
        """

        let items = UpgradePlan.parse(output, requested: ["firefox"], isCask: true)

        #expect(items.count == 1)
        #expect(items.first?.isCask == true)
    }
}
