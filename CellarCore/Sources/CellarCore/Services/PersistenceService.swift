import Foundation

// MARK: - CacheEntry

public struct CacheEntry<T: Codable>: Codable, Sendable where T: Sendable {
    public let data: T
    public let timestamp: Date

    public init(data: T, timestamp: Date = .now) {
        self.data = data
        self.timestamp = timestamp
    }

    public func isValid(maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < maxAge
    }
}

// MARK: - PersistenceService

public nonisolated final class PersistenceService: Sendable {
    private let baseURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseURL = appSupport.appendingPathComponent("Cellar", isDirectory: true)
    }

    // MARK: - Read

    public func load<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T {
        let url = fileURL(for: fileName)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    public func loadOrDefault<T: Decodable>(_ type: T.Type, from fileName: String, default defaultValue: T) -> T {
        (try? load(type, from: fileName)) ?? defaultValue
    }

    // MARK: - Write

    public func save<T: Encodable>(_ value: T, to fileName: String) throws {
        try ensureDirectoryExists()
        let url = fileURL(for: fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Cache

    /// Loads cached data and returns it along with freshness status.
    /// Returns `nil` if no cache exists or if decoding fails.
    public func loadCached<T: Codable & Sendable>(_ type: T.Type, from fileName: String, maxAge: TimeInterval) -> (data: T, isFresh: Bool)? {
        guard let entry = try? load(CacheEntry<T>.self, from: fileName) else { return nil }
        return (data: entry.data, isFresh: entry.isValid(maxAge: maxAge))
    }

    /// Wraps data in a `CacheEntry` with the current timestamp and saves it.
    public func saveToCache<T: Codable & Sendable>(_ data: T, to fileName: String) {
        let entry = CacheEntry(data: data)
        try? save(entry, to: fileName)
    }

    /// Checks whether a fresh fetch is needed, restoring cached data when the
    /// in-memory collection is empty.
    ///
    /// - Parameters:
    ///   - current: The in-memory data. If empty, the cache is restored into it.
    ///   - fileName: The cache file to read from.
    ///   - maxAge: Maximum age before the cache is considered stale.
    ///   - forceRefresh: When `true`, always indicates a fetch is needed.
    /// - Returns: A tuple of the (possibly restored) data and whether a fresh
    ///   fetch is still needed.
    public func restoreIfNeeded<T: Codable & Sendable>(
        current: [T],
        from fileName: String,
        maxAge: TimeInterval,
        forceRefresh: Bool
    ) -> (restored: [T], needsFetch: Bool) {
        guard let cached = loadCached([T].self, from: fileName, maxAge: maxAge) else {
            return (current, true)
        }
        let restored = current.isEmpty ? cached.data : current
        let needsFetch = forceRefresh || !cached.isFresh
        return (restored, needsFetch)
    }

    // MARK: - Delete

    public func delete(fileName: String) throws {
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func exists(fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
    }

    // MARK: - Private

    private func fileURL(for fileName: String) -> URL {
        baseURL.appendingPathComponent(fileName)
    }

    private func ensureDirectoryExists() throws {
        guard !FileManager.default.fileExists(atPath: baseURL.path) else { return }
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
}
