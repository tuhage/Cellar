import Foundation

/// UserDefaults keys of user settings, shared by the Settings window and the
/// code that honors them.
enum SettingsKey {
    static let showsMenuBarExtra = "showMenuBarExtra"
    static let serviceRefreshInterval = "refreshInterval"
    static let confirmsBeforeUninstall = "confirmBeforeUninstall"
    static let showsNotifications = "showNotifications"
    static let checksPackageUpdatesDaily = "checksPackageUpdatesAutomatically"
    static let selectedSettingsTab = "settingsSelectedTab"
}

/// The tabs of the Settings window.
enum SettingsTab: String {
    case general
    case maintenance
    case extensions
    case about

    /// Makes Settings open on `tab` next time, e.g. before `openSettings()`.
    static func select(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: SettingsKey.selectedSettingsTab)
    }
}
