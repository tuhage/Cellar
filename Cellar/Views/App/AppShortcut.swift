import SwiftUI

/// Every keyboard shortcut of the app, defined once so the menus and the
/// Keyboard Shortcuts window can't drift apart.
enum AppShortcut: CaseIterable {
    case quickOpen
    case showActivity
    case refresh
    case checkForPackageUpdates
    case upgradeAll
    case upgradeSelection
    case uninstallSelection
    case cleanUp
    case toggleService
    case restartService

    var key: KeyEquivalent {
        switch self {
        case .quickOpen: "k"
        case .showActivity: "a"
        case .refresh, .checkForPackageUpdates: "r"
        case .upgradeAll, .upgradeSelection: "u"
        case .uninstallSelection: .delete
        case .cleanUp: "k"
        case .toggleService: "s"
        case .restartService: "r"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .quickOpen, .refresh, .upgradeSelection, .uninstallSelection: .command
        case .showActivity, .upgradeAll, .cleanUp, .toggleService: [.command, .shift]
        case .checkForPackageUpdates: [.command, .option]
        case .restartService: [.command, .shift, .option]
        }
    }

    var title: String {
        switch self {
        case .quickOpen: "Quick Open"
        case .showActivity: "Show Activity"
        case .refresh: "Refresh"
        case .checkForPackageUpdates: "Check for Package Updates"
        case .upgradeAll: "Upgrade All"
        case .upgradeSelection: "Upgrade Selected Package"
        case .uninstallSelection: "Uninstall Selected Package"
        case .cleanUp: "Clean Up Homebrew"
        case .toggleService: "Start or Stop Selected Service"
        case .restartService: "Restart Selected Service"
        }
    }
}

// MARK: - Display

extension AppShortcut {

    enum Category: String, CaseIterable {
        case navigation = "Navigation"
        case packages = "Packages"
        case services = "Services"

        var systemImage: String {
            switch self {
            case .navigation: "sidebar.left"
            case .packages: "shippingbox"
            case .services: "gearshape.2"
            }
        }
    }

    var category: Category {
        switch self {
        case .quickOpen, .showActivity: .navigation
        case .refresh, .checkForPackageUpdates, .upgradeAll, .upgradeSelection, .uninstallSelection, .cleanUp: .packages
        case .toggleService, .restartService: .services
        }
    }

    /// "⇧⌘U" — modifiers in the order macOS menus show them.
    var symbols: String {
        let modifierSymbols: [(EventModifiers, String)] = [
            (.control, "\u{2303}"), (.option, "\u{2325}"), (.shift, "\u{21E7}"), (.command, "\u{2318}"),
        ]
        let prefix = modifierSymbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
        let keySymbol = key == .delete ? "\u{232B}" : String(key.character).uppercased()
        return prefix + keySymbol
    }
}

extension View {
    func shortcut(_ shortcut: AppShortcut) -> some View {
        keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}
