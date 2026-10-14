import Testing
import Foundation
@testable import CellarCore

@Suite("Brewfile bundle commands")
struct BrewfileBundleTests {

    private func fixture(_ name: String) throws -> String {
        String(decoding: try fixtureData(name), as: UTF8.self)
    }

    // MARK: Check

    @Test("brewfileCheck_parse_collectsMissingEntriesOfEveryKind")
    func brewfileCheck_parse_collectsMissingEntriesOfEveryKind() throws {
        let check = BrewfileCheck.parse(try fixture("bundle_check_verbose.txt"))

        #expect(check.missingEntryIDs == [
            "tap:homebrew/core",
            "cask:firefox",
            "vscode:ms-python.python",
            "mas:Final Cut Pro",
            "brew:wget",
            "brew:mobile-dev-inc/tap/maestro",
        ])
    }

    @Test("brewService_bundleCheck_treatsNonZeroExitAsFindings")
    func brewService_bundleCheck_treatsNonZeroExitAsFindings() async throws {
        let mock = MockBrewProcess(stubbedOutput: ProcessOutput(
            stdout: "", stderr: try fixture("bundle_check_verbose.txt"), exitCode: 1
        ))

        let check = try await BrewService(process: mock).bundleCheck(at: "/tmp/Brewfile")

        #expect(check.isMissing(BrewfileContent.Entry(keyword: "brew", name: "wget")))
    }

    @Test("brewService_bundleCheck_throwsOnBrewError")
    func brewService_bundleCheck_throwsOnBrewError() async throws {
        let mock = MockBrewProcess(stubbedOutput: ProcessOutput(
            stdout: "", stderr: "Error: Invalid Brewfile: unexpected token", exitCode: 1
        ))

        await #expect(throws: BrewError.self) {
            try await BrewService(process: mock).bundleCheck(at: "/tmp/Brewfile")
        }
    }

    // MARK: Cleanup

    @Test("brewfileCleanupPlan_parse_listsPackagesButNotCacheFiles")
    func brewfileCleanupPlan_parse_listsPackagesButNotCacheFiles() throws {
        let plan = BrewfileCleanupPlan.parse(try fixture("bundle_cleanup_dry_run.txt"))

        #expect(plan.items.map(\.id) == [
            "cask:android-commandlinetools",
            "brew:ada-url",
            "brew:icu4c@78",
            "brew:mobile-dev-inc/tap/maestro",
            "tap:mobile-dev-inc/tap",
            "mas:Final Cut Pro",
            "vscode:ms-python.python",
            "other:Some.Package",
        ])
    }

    @Test("brewfileCleanupPlan_parse_writesLinesThatKeepItems")
    func brewfileCleanupPlan_parse_writesLinesThatKeepItems() throws {
        let plan = BrewfileCleanupPlan.parse(try fixture("bundle_cleanup_dry_run.txt"))
        let lines = Dictionary(uniqueKeysWithValues: plan.items.map { ($0.id, $0.rawLine) })

        #expect(lines["mas:Final Cut Pro"] == "mas \"Final Cut Pro\", id: 424389933")
        #expect(lines["brew:ada-url"] == "brew \"ada-url\"")
        #expect(lines["other:Some.Package"] == "")
    }

    @Test("brewfileCleanupPlan_brewfileText_appendsKeptItems")
    func brewfileCleanupPlan_brewfileText_appendsKeptItems() {
        let kept = [BrewfileContent.Entry(keyword: "cask", name: "firefox")]

        let text = BrewfileCleanupPlan.brewfileText("brew \"wget\"\n", keeping: kept)

        #expect(BrewfileContent.parse(from: text).entries.map(\.id) == ["brew:wget", "cask:firefox"])
    }

    @Test("brewfileCleanupPlan_parse_emptyWhenNothingToRemove")
    func brewfileCleanupPlan_parse_emptyWhenNothingToRemove() {
        let plan = BrewfileCleanupPlan.parse("Would `brew cleanup`:\nWould remove: /tmp/x (1 file, 1KB)\n")
        #expect(plan.isEmpty)
    }
}
