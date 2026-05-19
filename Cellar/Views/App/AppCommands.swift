import SwiftUI
import CellarCore

// MARK: - AppCommands

/// Keyboard shortcut commands for the Cellar menu bar.
///
/// Uses `NotificationCenter` to communicate actions to views, since
/// `Commands` structs cannot directly access `@Environment` stores.
struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) { }

        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") {
                openWindow(id: "keyboard-shortcuts")
            }
        }

        CommandGroup(after: .appInfo) {
            CheckForUpdatesMenuButton()
        }

        CommandMenu("Packages") {
            Button("Refresh All") {
                NotificationCenter.default.post(name: .refreshAll, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Upgrade All") {
                NotificationCenter.default.post(name: .upgradeAll, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])

            Divider()

            Button("Cleanup") {
                NotificationCenter.default.post(name: .cleanup, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        CommandMenu("Services") {
            Button("Refresh Services") {
                NotificationCenter.default.post(name: .refreshServices, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }
    }
}

// MARK: - CheckForUpdatesMenuButton

/// A `View` wrapper so we can access `@Environment(\.openSettings)` from
/// within the `Commands` DSL, which does not support environment directly.
private struct CheckForUpdatesMenuButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Check for Updates\u{2026}") {
            openSettings()
            NotificationCenter.default.post(name: .checkForUpdates, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let refreshAll = Notification.Name("cellar.refreshAll")
    static let upgradeAll = Notification.Name("cellar.upgradeAll")
    static let cleanup = Notification.Name("cellar.cleanup")
    static let refreshServices = Notification.Name("cellar.refreshServices")
    static let checkForUpdates = Notification.Name("cellar.checkForUpdates")
}
