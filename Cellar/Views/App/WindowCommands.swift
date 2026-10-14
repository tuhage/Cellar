import SwiftUI

/// An async action passed through the environment or focused values.
/// Call it like a function.
struct AsyncAction {
    let action: @MainActor () async -> Void

    @MainActor
    func callAsFunction() async {
        await action()
    }
}

/// What the menu commands can do in the frontmost main window. Published by
/// `ContentView`; the commands are disabled when no main window is focused.
struct WindowCommands {
    let navigate: (SidebarItem) -> Void
    let openQuickOpen: () -> Void
    let showActivity: () -> Void
    let refreshAll: AsyncAction
    let canUpgradeAll: Bool
    let previewUpgradeAll: () -> Void
    let canCleanUp: Bool
    let previewCleanup: () -> Void
    let canCheckForUpdates: Bool
    let checkForPackageUpdates: () -> Void
}

/// The service selected on the page in the frontmost window.
struct SelectedServiceCommands {
    let name: String
    let isRunning: Bool
    let isBusy: Bool
    let start: () -> Void
    let stop: () -> Void
    let restart: () -> Void
}

/// The package selected on the page in the frontmost window.
struct SelectedPackageCommands {
    let name: String
    let isBusy: Bool
    let canUpgrade: Bool
    /// `nil` for casks, which can't be pinned.
    let isPinned: Bool?
    let upgrade: () -> Void
    let togglePin: () -> Void
    /// Asks for confirmation before uninstalling.
    let uninstall: () -> Void
}

extension FocusedValues {
    @Entry var windowCommands: WindowCommands?
    /// Reloads the page in the frontmost window (⌘R).
    @Entry var pageRefresh: AsyncAction?
    @Entry var selectedService: SelectedServiceCommands?
    @Entry var selectedPackage: SelectedPackageCommands?
}

extension EnvironmentValues {
    /// Reloads the package, service and tap lists.
    @Entry var refreshAll = AsyncAction {}
    /// Loads data and keeps it current until cancelled; see `AppStores.start()`.
    @Entry var startBackgroundWork = AsyncAction {}
}
