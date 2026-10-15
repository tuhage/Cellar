import AppKit
import CellarCore
import Observation
import os
import Sparkle

// MARK: - UpdateStore

/// Owns Cellar's Sparkle updater and exposes its user-facing preferences to SwiftUI.
/// Sparkle reads the signed GitHub Releases appcast configured in Info.plist.
/// A copy installed with Homebrew updates through brew instead.
@Observable
@MainActor
final class UpdateStore {
    private let controller: SPUStandardUpdaterController

    /// Homebrew installed this copy, so brew updates it like any other cask
    /// and Sparkle stays off: two updaters would leave brew's record of the
    /// installed version behind.
    let isManagedByHomebrew: Bool

    /// The version brew installed while this copy kept running. brew doesn't
    /// quit Cellar when Cellar itself runs the upgrade, so it takes a relaunch.
    private(set) var versionAwaitingRelaunch: String?

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
        let isManagedByHomebrew = Self.isInstalledByHomebrew()
        let controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater && !isManagedByHomebrew,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        self.isManagedByHomebrew = isManagedByHomebrew
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

    // MARK: - Homebrew

    /// brew's name for Cellar's cask, in the tuhage/cellar tap.
    private static let caskToken = "cellar"

    /// brew moves a cask's app into an Applications folder and keeps a record
    /// of it in its Caskroom.
    private static func isInstalledByHomebrew() -> Bool {
        guard Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Applications" else {
            return false
        }
        let prefix = URL(filePath: BrewProcess.resolveBrewPath())
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let record = prefix.appending(path: "Caskroom/\(caskToken)")
        return FileManager.default.fileExists(atPath: record.path(percentEncoded: false))
    }

    /// Notices when brew replaced Cellar on disk with another build.
    func checkInstalledCopy() {
        let infoURL = Bundle.main.bundleURL.appending(path: "Contents/Info.plist")
        guard isManagedByHomebrew, let installed = NSDictionary(contentsOf: infoURL) else { return }

        let buildKey = kCFBundleVersionKey as String
        let isRunningBuild = installed[buildKey] as? String == Bundle.main.infoDictionary?[buildKey] as? String
        versionAwaitingRelaunch = isRunningBuild ? nil : installed["CFBundleShortVersionString"] as? String
    }

    /// Quits Cellar and opens the copy on disk once this one has exited, so
    /// the two never run side by side.
    func relaunch() {
        let reopen = Process()
        reopen.executableURL = URL(filePath: "/bin/sh")
        reopen.arguments = [
            "-c", #"while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; /usr/bin/open "$0""#,
            Bundle.main.bundlePath,
            String(ProcessInfo.processInfo.processIdentifier),
        ]
        do {
            try reopen.run()
            NSApplication.shared.terminate(nil)
        } catch {
            Log.updates.error("Could not relaunch Cellar: \(error.localizedDescription, privacy: .public)")
        }
    }
}
