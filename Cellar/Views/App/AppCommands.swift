import SwiftUI
import CellarCore

// MARK: - AppCommands

/// The app's menu commands. They act on the frontmost main window through
/// focused values, so each item is enabled only when it can do something.
struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.windowCommands) private var window
    @FocusedValue(\.pageRefresh) private var pageRefresh
    @FocusedValue(\.selectedPackage) private var package
    @FocusedValue(\.selectedService) private var service
    let updateStore: UpdateStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) { }

        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") {
                openWindow(id: SceneID.keyboardShortcuts)
            }
            .keyboardShortcut("/", modifiers: .command)
        }

        CommandGroup(after: .appInfo) {
            Button("Check for Cellar Updates\u{2026}") {
                updateStore.checkForUpdates()
            }
        }

        CommandMenu("Navigate") {
            Button("Quick Open\u{2026}") { window?.openQuickOpen() }
                .shortcut(.quickOpen)
                .disabled(window == nil)

            Button("Show Activity") { window?.showActivity() }
                .shortcut(.showActivity)
                .disabled(window == nil)

            Divider()

            ForEach(Array(SidebarItem.allCases.prefix(9).enumerated()), id: \.element.id) { index, item in
                Button(item.title) { window?.navigate(item) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                    .disabled(window == nil)
            }
        }

        CommandMenu("Packages") {
            Button("Reload") { reload() }
                .shortcut(.reload)
                .disabled(window == nil)

            Button("Check for Package Updates") { window?.checkForPackageUpdates() }
                .shortcut(.checkForPackageUpdates)
                .disabled(window?.canCheckForUpdates != true)

            Button("Upgrade All\u{2026}") { window?.previewUpgradeAll() }
                .shortcut(.upgradeAll)
                .disabled(window?.canUpgradeAll != true)

            Divider()

            Button(package.map { "Upgrade \($0.name)" } ?? "Upgrade") { package?.upgrade() }
                .shortcut(.upgradeSelection)
                .disabled(package?.canUpgrade != true || package?.isBusy == true)

            Button(package?.isPinned == true ? "Unpin" : "Pin") { package?.togglePin() }
                .disabled(package?.isPinned == nil || package?.isBusy == true)

            Button(package.map { "Uninstall \($0.name)\u{2026}" } ?? "Uninstall\u{2026}") { package?.uninstall() }
                .shortcut(.uninstallSelection)
                .disabled(package == nil || package?.isBusy == true)

            Divider()

            Button("Clean Up\u{2026}") { window?.previewCleanup() }
                .shortcut(.cleanUp)
                .disabled(window?.canCleanUp != true)
        }

        CommandMenu("Services") {
            Button(service?.isRunning == true ? "Stop" : "Start") {
                guard let service else { return }
                service.isRunning ? service.stop() : service.start()
            }
            .shortcut(.toggleService)
            .disabled(service == nil || service?.isBusy == true)

            Button("Restart") { service?.restart() }
                .shortcut(.restartService)
                .disabled(service?.isRunning != true || service?.isBusy == true)
        }
    }

    /// ⌘R reloads the visible page, or everything when the page has none.
    private func reload() {
        Task {
            if let pageRefresh {
                await pageRefresh()
            } else {
                await window?.refreshAll()
            }
        }
    }
}
