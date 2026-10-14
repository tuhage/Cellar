import Foundation

// MARK: - HomebrewDiskUsage

/// Disk space Homebrew uses: its prefix — which normally contains the Cellar
/// and Caskroom — and the download cache, which by default lives outside it
/// (`~/Library/Caches/Homebrew`).
public struct HomebrewDiskUsage: Codable, Hashable, Sendable {

    // MARK: Data

    public let prefix: Location
    public let cellar: Location
    public let caskroom: Location
    public let cache: Location

    public init(prefix: Location, cellar: Location, caskroom: Location, cache: Location) {
        self.prefix = prefix
        self.cellar = cellar
        self.caskroom = caskroom
        self.cache = cache
    }

    public struct Location: Codable, Hashable, Sendable {
        public let path: String
        public let bytes: Int64

        public init(path: String, bytes: Int64) {
            self.path = path
            self.bytes = bytes
        }

        /// Whether this directory lies within `other`.
        public func isInside(_ other: Location) -> Bool {
            path.hasPrefix(other.path.hasSuffix("/") ? other.path : other.path + "/")
        }
    }

    // MARK: Breakdown

    public enum Area: Hashable, Sendable {
        case cellar, caskroom, otherFiles, cache

        public var title: String {
            switch self {
            case .cellar: "Cellar"
            case .caskroom: "Caskroom"
            case .otherFiles: "Other Homebrew Files"
            case .cache: "Download Cache"
            }
        }
    }

    public struct Segment: Identifiable, Hashable, Sendable {
        public let area: Area
        public let bytes: Int64
        public var id: Area { area }
    }

    /// Non-overlapping parts that add up to `totalBytes`. Directories inside
    /// the prefix are carved out of it rather than added on top, so the
    /// parts never exceed the total — even when sizes measured a moment
    /// apart disagree slightly.
    public var segments: [Segment] {
        let insidePrefix = [cellar, caskroom, cache].filter { $0.isInside(prefix) }.map(\.bytes).reduce(0, +)
        return [
            Segment(area: .cellar, bytes: cellar.bytes),
            Segment(area: .caskroom, bytes: caskroom.bytes),
            Segment(area: .otherFiles, bytes: max(prefix.bytes - insidePrefix, 0)),
            Segment(area: .cache, bytes: cache.bytes),
        ]
    }

    /// Everything Homebrew occupies, the prefix and whatever lies outside it.
    public var totalBytes: Int64 {
        segments.map(\.bytes).reduce(0, +)
    }

    /// The segment's share of `totalBytes`, from 0 to 1.
    public func fraction(of segment: Segment) -> Double {
        totalBytes > 0 ? Double(segment.bytes) / Double(totalBytes) : 0
    }

    // MARK: Factory Methods

    /// Asks brew where its directories are (honouring `HOMEBREW_CACHE` and
    /// friends) and measures them.
    public static func measure() async throws -> HomebrewDiskUsage {
        async let prefix = location(.prefix)
        async let cellar = location(.cellar)
        async let caskroom = location(.caskroom)
        async let cache = location(.cache)
        return try await HomebrewDiskUsage(prefix: prefix, cellar: cellar, caskroom: caskroom, cache: cache)
    }

    private static func location(_ directory: BrewDirectory) async throws -> Location {
        let path = try await BrewService.shared.path(of: directory)
        return Location(path: path, bytes: try allocatedSize(of: URL(fileURLWithPath: path)))
    }

    /// Bytes allocated on disk for every file under `url`, without following
    /// symlinks. A missing directory (no casks installed yet) is empty.
    static func allocatedSize(of url: URL) throws -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            try Task.checkCancellation()
            guard let values = try? file.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: Preview

    public static var preview: HomebrewDiskUsage {
        HomebrewDiskUsage(
            prefix: Location(path: "/opt/homebrew", bytes: 7_550_000_000),
            cellar: Location(path: "/opt/homebrew/Cellar", bytes: 6_180_000_000),
            caskroom: Location(path: "/opt/homebrew/Caskroom", bytes: 12_000),
            cache: Location(path: "/Users/me/Library/Caches/Homebrew", bytes: 488_000_000)
        )
    }
}
