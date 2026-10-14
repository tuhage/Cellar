import Foundation
import Observation
import CellarCore

/// How much disk space Homebrew uses. Measuring walks every file in the
/// prefix and the cache, so the last result is cached and shown at once.
@Observable
@MainActor
final class DiskUsageStore: LoadableStore {
    var usage: HomebrewDiskUsage?

    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    private static let cache = CachePolicy(fileName: "cache-disk-usage.json", maxAge: 600)

    func load(force: Bool = false) async {
        await load(
            cache: Self.cache,
            force: force,
            failureMessage: "Disk usage couldn’t be measured.",
            fetch: { try await HomebrewDiskUsage.measure() },
            apply: { self.usage = $0 }
        )
    }

    /// Re-measures after something freed space — only once usage has been
    /// shown, so background maintenance doesn't walk the disk for nothing.
    func reloadIfLoaded() async {
        guard usage != nil else { return }
        await load(force: true)
    }
}
