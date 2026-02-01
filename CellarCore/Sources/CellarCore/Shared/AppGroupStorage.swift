import Foundation

/// Provides shared storage via App Group container for cross-target data sharing
/// (main app, widget, Finder extension).
public enum AppGroupStorage {
    public static let groupIdentifier = "group.com.tuhage.Cellar"

    /// Returns the shared App Group container URL.
    ///
    /// `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil`
    /// for non-sandboxed apps, so we fall back to the well-known path that
    /// macOS uses for group containers.
    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) {
            return url
        }

        // Non-sandboxed fallback — same path macOS uses for group containers.
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home
            .appendingPathComponent("Library/Group Containers")
            .appendingPathComponent(groupIdentifier)

        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Reads a `Decodable` value from the shared container.
    public static func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = containerURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Writes an `Encodable` value to the shared container.
    public static func save<T: Encodable>(_ value: T, to fileName: String) {
        let url = containerURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
