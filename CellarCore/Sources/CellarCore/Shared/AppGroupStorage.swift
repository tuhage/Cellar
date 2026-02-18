import Foundation
import os

/// Provides shared storage via App Group container for cross-target data sharing
/// (main app, widget, Finder extension).
public enum AppGroupStorage {
    private static let logger = Logger(subsystem: "com.tuhage.Cellar", category: "AppGroupStorage")

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

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create App Group container directory: \(error.localizedDescription, privacy: .public)")
        }
        return url
    }

    /// Reads a `Decodable` value from the shared container.
    public static func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = containerURL.appendingPathComponent(fileName)

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.warning("Failed to read '\(fileName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return nil
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Failed to decode '\(fileName, privacy: .public)' as \(String(describing: type), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Writes an `Encodable` value to the shared container.
    public static func save<T: Encodable>(_ value: T, to fileName: String) {
        let url = containerURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            logger.error("Failed to encode '\(fileName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to write '\(fileName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Shared UserDefaults

    /// UserDefaults shared across all targets via App Group.
    public static nonisolated(unsafe) let sharedDefaults = UserDefaults(suiteName: groupIdentifier)

    /// Key for the Finder Sync monitored directory paths.
    public static let finderSyncPathsKey = "finderSyncMonitoredPaths"

    /// Default directories for Finder Sync monitoring (non-TCC-protected only).
    public static let defaultFinderSyncPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Projects", "Developer"].map {
            home.appendingPathComponent($0).path
        }
    }()

    /// The currently configured Finder Sync monitored paths.
    public static var finderSyncPaths: [String] {
        get {
            sharedDefaults?.stringArray(forKey: finderSyncPathsKey) ?? defaultFinderSyncPaths
        }
        set {
            sharedDefaults?.set(newValue, forKey: finderSyncPathsKey)
        }
    }
}
