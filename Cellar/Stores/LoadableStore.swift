import Foundation
import CellarCore

/// Loading and error state shared by stores that list data from brew.
///
/// `isLoading` and `errorMessage` describe loading only. Actions (install,
/// start, cleanup…) run through `ActivityStore.perform`, which reports their
/// progress and failures.
@MainActor
protocol LoadableStore: AnyObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
    /// When the data was last fetched from brew.
    var lastUpdated: Date? { get set }
}

/// Where a brew listing is cached and how long it stays fresh.
struct CachePolicy {
    let fileName: String
    var maxAge: TimeInterval = 300
}

extension LoadableStore {

    /// Shows cached data at once, then fetches from brew when the cache is
    /// stale or `force` is set. A failed fetch keeps what is showing and
    /// reports `failureMessage`.
    func load<Value: Codable & Sendable>(
        cache: CachePolicy,
        force: Bool = false,
        failureMessage: String,
        fetch: @MainActor () async throws -> Value,
        apply: @MainActor (Value) -> Void
    ) async {
        let persistence = PersistenceService()
        if lastUpdated == nil, let entry = persistence.loadCacheEntry(Value.self, from: cache.fileName) {
            apply(entry.data)
            lastUpdated = entry.timestamp
        }
        if let lastUpdated, !force, Date().timeIntervalSince(lastUpdated) < cache.maxAge {
            return
        }
        guard force || !isLoading else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            let value = try await fetch()
            apply(value)
            lastUpdated = Date()
            errorMessage = nil
            persistence.saveToCache(value, to: cache.fileName)
        } catch {
            if !isOperationCancellation(error) {
                errorMessage = failureMessage
            }
        }
    }
}
