import Foundation
import Testing
@testable import CellarCore

@Suite("Cleanup Plan")
struct CleanupPlanTests {

    private static let cachePath = "/Users/me/Library/Caches/Homebrew"

    private func fixture(_ name: String) throws -> String {
        try String(decoding: fixtureData(name), as: UTF8.self)
    }

    @Test("cleanupPlan_parse_groupsDryRunByCategory")
    func cleanupPlan_parse_groupsDryRunByCategory() throws {
        let plan = CleanupPlan.parse(try fixture("cleanup_dry_run.txt"), cachePath: Self.cachePath)

        #expect(plan.groups.map(\.category) == [.oldVersions, .unusedDependencies, .downloads, .logs, .other])
        let oldVersions = try #require(plan.groups.first { $0.category == .oldVersions })
        #expect(oldVersions.items.map(\.title) == ["ca-certificates 2026-05-14", "node 26.5.0", "openjdk 26.0.1", "firefox 140.0"])
        #expect(oldVersions.bytes == 199_200 + 88_600_000 + 398_000_000 + 1_200_000)
        let dependencies = try #require(plan.groups.first { $0.category == .unusedDependencies })
        #expect(dependencies.items.map(\.title) == ["libnghttp3", "libngtcp2"])
        #expect(plan.reclaimableBytes == 573_300_000)
    }

    @Test("cleanupPlan_parse_readsDownloadsPrunesAndOtherFiles")
    func cleanupPlan_parse_readsDownloadsPrunesAndOtherFiles() throws {
        let plan = CleanupPlan.parse(try fixture("cleanup_dry_run.txt"), cachePath: Self.cachePath)

        let downloads = try #require(plan.groups.first { $0.category == .downloads })
        #expect(downloads.items.map(\.title) == [
            "portable-ruby-4.0.7.arm64_big_sur.bottle.tar.gz",
            "android-commandlinetools--15859902.zip",
            "3 files in api-source",
        ])
        #expect(downloads.items[1].bytes == 0)
        #expect(downloads.items[2].bytes == nil)

        let other = try #require(plan.groups.first { $0.category == .other })
        #expect(other.items.map(\.path) == [
            "/opt/homebrew/var/homebrew/tmp/.cellar/openssl@3",
            "/opt/homebrew/lib/gio/modules",
            "/opt/homebrew/Library/Homebrew/vendor/portable-ruby/4.0.5_1",
        ])
    }

    @Test("cleanupPlan_parse_usesCustomCachePath")
    func cleanupPlan_parse_usesCustomCachePath() {
        let plan = CleanupPlan.parse("Would remove: /Volumes/Fast/brew-cache/wget--1.0.tar.gz (1MB)", cachePath: "/Volumes/Fast/brew-cache")

        #expect(plan.items.first?.category == .downloads)
    }

    @Test("cleanupPlan_parse_readsRealRunForSummary")
    func cleanupPlan_parse_readsRealRunForSummary() throws {
        let plan = CleanupPlan.parse(try fixture("cleanup_run.txt"))

        #expect(plan.items.map(\.title) == [
            "node 26.5.0", "openjdk 26.0.1", "libngtcp2",
            "portable-ruby-4.0.7.arm64_big_sur.bottle.tar.gz", "3 files in api-source",
        ])
        #expect(plan.items.first?.path == "/opt/homebrew/Cellar/node/26.5.0")
        #expect(plan.reclaimableBytes == 1_200_000_000)
        #expect(plan.resultSummary == "Freed \(Int64(1_200_000_000).formatted(.byteCount(style: .file))) · 5 items")
    }

    @Test("cleanupPlan_parse_emptyOutputIsTidy")
    func cleanupPlan_parse_emptyOutputIsTidy() {
        let plan = CleanupPlan.parse("Warning: Skipping gradle: most recent version 9.8.1 not installed\n")

        #expect(plan.isEmpty)
        #expect(plan.reclaimableBytes == nil)
        #expect(plan.resultSummary == "Nothing to clean up. Homebrew is tidy.")
    }

    @Test("cleanupPlan_parse_readsAutoremoveDryRun")
    func cleanupPlan_parse_readsAutoremoveDryRun() {
        let plan = CleanupPlan.parse("==> Would autoremove 2 unneeded formulae:\nlibnghttp3\nuser/tap/libfoo\n")

        #expect(plan.items.map(\.title) == ["libnghttp3", "user/tap/libfoo"])
        #expect(plan.items.allSatisfy { $0.category == .unusedDependencies })
        #expect(plan.autoremoveSummary == "Removed libnghttp3 and user/tap/libfoo.")
        #expect(CleanupPlan.parse("").autoremoveSummary == "No unused dependencies to remove.")
    }

    @Test("brewService_cleanup_passesDepthArguments")
    func brewService_cleanup_passesDepthArguments() async throws {
        let process = RecordingBrewProcess()
        let service = BrewService(process: process)

        for try await _ in service.cleanup() {}
        for try await _ in service.cleanup(.deep) {}

        #expect(process.streamedArguments == [["cleanup"], ["cleanup", "--prune=all", "-s"]])
    }
}
