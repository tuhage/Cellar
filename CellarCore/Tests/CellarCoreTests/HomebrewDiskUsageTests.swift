import Foundation
import Testing
@testable import CellarCore

@Suite("Homebrew Disk Usage")
struct HomebrewDiskUsageTests {

    private typealias Location = HomebrewDiskUsage.Location

    private func usage(prefix: Int64, cellar: Int64, caskroom: Int64, cache: Int64, cachePath: String = "/Users/me/Library/Caches/Homebrew") -> HomebrewDiskUsage {
        HomebrewDiskUsage(
            prefix: Location(path: "/opt/homebrew", bytes: prefix),
            cellar: Location(path: "/opt/homebrew/Cellar", bytes: cellar),
            caskroom: Location(path: "/opt/homebrew/Caskroom", bytes: caskroom),
            cache: Location(path: cachePath, bytes: cache)
        )
    }

    private func bytes(_ usage: HomebrewDiskUsage) -> [HomebrewDiskUsage.Area: Int64] {
        Dictionary(uniqueKeysWithValues: usage.segments.map { ($0.area, $0.bytes) })
    }

    @Test("diskUsage_segments_addCacheOutsidePrefix")
    func diskUsage_segments_addCacheOutsidePrefix() {
        let usage = usage(prefix: 1_000, cellar: 700, caskroom: 100, cache: 400)

        #expect(bytes(usage) == [.cellar: 700, .caskroom: 100, .otherFiles: 200, .cache: 400])
        #expect(usage.totalBytes == 1_400)
    }

    @Test("diskUsage_segments_carveCacheInsidePrefix")
    func diskUsage_segments_carveCacheInsidePrefix() {
        let usage = usage(prefix: 1_000, cellar: 700, caskroom: 100, cache: 150, cachePath: "/opt/homebrew/cache")

        #expect(bytes(usage)[.otherFiles] == 50)
        #expect(usage.totalBytes == 1_000)
    }

    @Test("diskUsage_segments_neverExceedTotal")
    func diskUsage_segments_neverExceedTotal() {
        // Sizes measured a moment apart can disagree.
        let usage = usage(prefix: 900, cellar: 950, caskroom: 0, cache: 100)

        #expect(bytes(usage)[.otherFiles] == 0)
        #expect(usage.segments.map { usage.fraction(of: $0) }.reduce(0, +) <= 1)
    }

    @Test("diskUsage_location_siblingWithSharedPrefixIsOutside")
    func diskUsage_location_siblingWithSharedPrefixIsOutside() {
        let prefix = Location(path: "/opt/homebrew", bytes: 0)

        #expect(Location(path: "/opt/homebrew/Cellar", bytes: 0).isInside(prefix))
        #expect(!Location(path: "/opt/homebrew-cache", bytes: 0).isInside(prefix))
    }

    @Test("diskUsage_allocatedSize_sumsFilesAndToleratesMissingDirectory")
    func diskUsage_allocatedSize_sumsFilesAndToleratesMissingDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(count: 10_000).write(to: directory.appendingPathComponent("nested/file"))

        #expect(try HomebrewDiskUsage.allocatedSize(of: directory) >= 10_000)
        #expect(try HomebrewDiskUsage.allocatedSize(of: directory.appendingPathComponent("missing")) == 0)
    }
}
