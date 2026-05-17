import os

// MARK: - Cellar Logger Namespace

/// Centralised `os.Logger` instances for all Cellar targets.
///
/// Subsystem is always `com.tuhage.Cellar` so all logs appear together in
/// Console.app when filtered by subsystem. Categories group logs by feature.
///
/// Usage:
///   `Log.notifications.error("...")`
///   `Log.persistence.warning("...")`
public enum Log {
    /// Homebrew CLI process execution (BrewProcess, BrewService)
    public static let brew         = Logger(subsystem: subsystem, category: "brew")
    /// App Group container persistence (WidgetSnapshot etc.)
    public static let storage      = Logger(subsystem: subsystem, category: "storage")
    /// PersistenceService cache and document read/write
    public static let persistence  = Logger(subsystem: subsystem, category: "persistence")
    /// UNUserNotification scheduling and permission
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")
    /// CLI tool symlink installation
    public static let cliInstall   = Logger(subsystem: subsystem, category: "cli-install")
    /// ResourceStore (ps / du system commands)
    public static let resources    = Logger(subsystem: subsystem, category: "resources")
    /// CoreSpotlight indexing
    public static let spotlight    = Logger(subsystem: subsystem, category: "spotlight")
    /// App-level lifecycle, URL routing, environment
    public static let app          = Logger(subsystem: subsystem, category: "app")

    private static let subsystem = "com.tuhage.Cellar"
}
