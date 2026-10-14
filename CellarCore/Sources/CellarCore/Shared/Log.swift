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
    /// App Group container persistence (WidgetSnapshot etc.)
    public static let storage      = Logger(subsystem: subsystem, category: "storage")
    /// PersistenceService cache and document read/write
    public static let persistence  = Logger(subsystem: subsystem, category: "persistence")
    /// UNUserNotification scheduling and permission
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")
    /// CLI tool symlink installation
    public static let cliInstall   = Logger(subsystem: subsystem, category: "cli-install")
    /// CoreSpotlight indexing
    public static let spotlight    = Logger(subsystem: subsystem, category: "spotlight")
    /// Activity log files written to ~/Library/Logs/Cellar
    public static let activity     = Logger(subsystem: subsystem, category: "activity")

    private static let subsystem = "com.tuhage.Cellar"
}
