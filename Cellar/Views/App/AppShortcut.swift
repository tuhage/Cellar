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

extension View {
    func shortcut(_ shortcut: AppShortcut) -> some View {
        keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}
