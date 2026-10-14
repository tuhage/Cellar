import Foundation
import CellarCore

/// Moves the main window to a page, optionally selecting an item there.
///
/// The page is stored in user defaults, which `ContentView` reads, so every
/// way in — sidebar, rows that open an item, the menu bar, Spotlight, links —
/// navigates the same way, even without a focused window.
@MainActor
enum Navigator {

    static func show(_ item: SidebarItem) {
        UserDefaults.standard.set(item.rawValue, forKey: SettingsKey.selectedSidebarItem)
    }

    /// Selects an installed package on its Formulae or Casks page.
    static func show(_ package: PackageID, in store: PackageStore) {
        store.list(package.kind).select(package)
        show(package.kind.sidebarItem)
    }

    /// Searches Homebrew for a package that isn't installed.
    static func search(for package: PackageID, in store: PackageStore) {
        store.list(package.kind).showHomebrewResults(for: package.name)
        show(package.kind.sidebarItem)
    }

    static func show(service name: String, in store: ServiceStore) {
        store.selectedServiceId = name
        show(.services)
    }
}
