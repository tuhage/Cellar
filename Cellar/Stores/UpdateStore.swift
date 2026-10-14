import Foundation
import Observation
import Sparkle

// MARK: - UpdateStore

/// Owns Cellar's Sparkle updater and exposes its user-facing preferences to SwiftUI.
/// Sparkle reads the signed GitHub Releases appcast configured in Info.plist.
@Observable
@MainActor
final class UpdateStore {
    private let controller: SPUStandardUpdaterController

    var automaticallyChecksForUpdates: Bool {
        didSet {
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            if !automaticallyChecksForUpdates, automaticallyDownloadsUpdates {
                automaticallyDownloadsUpdates = false
            }
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        didSet {
            controller.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }

    private(set) var lastChecked: Date?

    init(startingUpdater: Bool = true) {
        let controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        self.automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = controller.updater.automaticallyDownloadsUpdates
        self.lastChecked = controller.updater.lastUpdateCheckDate
    }

    /// Presents Sparkle's standard update UI. The downloaded archive is verified
    /// with Cellar's Ed25519 key and Developer ID signature before installation.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
        refreshPreferences()
    }

    func refreshPreferences() {
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = controller.updater.automaticallyDownloadsUpdates
        lastChecked = controller.updater.lastUpdateCheckDate
    }

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
    }

}
