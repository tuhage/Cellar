import Foundation

/// Every UserDefaults key Cellar stores: user settings, shared by the
/// Settings window and the code that honors them, and remembered window
/// state such as sort orders and inspector widths.
///
/// Raw values are lowerCamelCase. A value can't change without losing what
/// users stored under it, so a renamed key goes into `renamedKeys`, which
/// `migrateRenamedKeys()` moves at launch.
enum SettingsKey {

    // MARK: Settings Window

    static let showsMenuBarExtra = "showMenuBarExtra"
    static let serviceRefreshInterval = "refreshInterval"
    static let confirmsBeforeUninstall = "confirmBeforeUninstall"
    static let showsNotifications = "showNotifications"
    static let checksPackageUpdatesDaily = "checksPackageUpdatesAutomatically"
    static let selectedSettingsTab = "settingsSelectedTab"

    // MARK: Window State

    static let selectedSidebarItem = "selectedSidebarItem"
    static let quickOpenRecentItems = "quickOpenRecentItems"
    static let lastHomebrewUpdateCheck = "lastHomebrewUpdateCheck"
    static let registersProjectServicesAtLogin = "projectServicesRegisterAtLogin"
    static let showsHiddenServices = "showsHiddenServices"
    static let hiddenServiceNames = "hiddenServiceNames"
    static let serviceColumns = "serviceColumns"
    static let dependencySearchScope = "dependencySearchScope"
    static let dependencyFilter = "dependencyFilter"

    /// Prefix of a table's sort order; `SortOrderStorage` appends the parts.
    static func sortOrder(_ table: String) -> String {
        "\(table)Sort"
    }

    static func showsInspector(_ page: InspectorPage) -> String {
        "\(page.rawValue)InspectorPresented"
    }

    // MARK: Migration

    /// Old raw value → current one.
    private static let renamedKeys: [String: String] = [
        "com.tuhage.Cellar.services.showsHidden": showsHiddenServices,
        "com.tuhage.Cellar.services.hiddenNames": hiddenServiceNames,
        "services.columns": serviceColumns,
        "services.showsInspector": showsInspector(.service),
        "showsPackageInspector": showsInspector(.package),
        "services.sort.column": sortOrder("service") + ".column",
        "services.sort.ascending": sortOrder("service") + ".ascending",
        "tapSortOrder.column": sortOrder("tap") + ".column",
        "tapSortOrder.ascending": sortOrder("tap") + ".ascending",
    ]

    /// Moves values stored under a key's old name to its current one.
    static func migrateRenamedKeys(in defaults: UserDefaults = .standard) {
        for (old, new) in renamedKeys {
            guard let value = defaults.object(forKey: old) else { continue }
            if defaults.object(forKey: new) == nil {
                defaults.set(value, forKey: new)
            }
            defaults.removeObject(forKey: old)
        }
    }
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
