import Foundation
import os

/// Provides shared storage via App Group container for cross-target data sharing
/// (main app, widget, Finder extension).
public enum AppGroupStorage {
    private static let logger = Log.storage

    /// Team-ID-prefixed groups are authorized directly from the code signature
    /// on macOS and don't require the identifier in a provisioning profile.
    public static let groupIdentifier = "23H73A78A7.com.tuhage.Cellar"

    /// Returns the shared App Group container URL.
    ///
    /// If the entitlement cannot be authorized, use target-local Application
    /// Support storage. Never address `~/Library/Group Containers` manually:
    /// macOS 15+ protects those paths and correctly prompts for access when the
    /// caller isn't recognized as a member of the group.
    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) {
            return url
        }

        logger.error("App Group container is unavailable; using target-local storage")
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let url = appSupport
            .appendingPathComponent("Cellar", isDirectory: true)
            .appendingPathComponent("Shared", isDirectory: true)

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
            // .atomic can fail in App Group containers — fall back to direct write.
            logger.warning("Atomic write failed for '\(fileName, privacy: .public)', retrying direct write: \(error.localizedDescription, privacy: .public)")
            do {
                try data.write(to: url)
            } catch {
                logger.error("Failed to write '\(fileName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            }
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
