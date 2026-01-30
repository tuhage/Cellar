import Foundation

/// Provides shared storage via App Group container for cross-target data sharing
/// (main app, widget, Finder extension).
public enum AppGroupStorage {
    public static let groupIdentifier = "group.com.tuhage.Cellar"

    /// Returns the shared App Group container URL, falling back to temp directory.
    public static var containerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) ?? FileManager.default.temporaryDirectory
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
