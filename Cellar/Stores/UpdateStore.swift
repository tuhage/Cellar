import Foundation
import Observation
import CellarCore

// MARK: - UpdateStore

@Observable
@MainActor
final class UpdateStore: LoadableStore {
    var isLoading: Bool = false
    var errorMessage: String?

    var latestRelease: ReleaseInfo?
    var lastChecked: Date?

    private let service: UpdateService
    private let defaults: UserDefaults

    private static let lastCheckKey = "com.tuhage.Cellar.update.lastCheck"
    private static let dismissedVersionKey = "com.tuhage.Cellar.update.dismissedVersion"

    init(service: UpdateService = UpdateService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        if let timestamp = defaults.object(forKey: Self.lastCheckKey) as? Date {
            self.lastChecked = timestamp
        }
    }

    /// Force a fresh check (ignores cache).
    func check() async {
        await withLoading {
            let release = try await service.fetchLatestRelease()
            self.latestRelease = release
            let now = Date()
            self.lastChecked = now
            self.defaults.set(now, forKey: Self.lastCheckKey)
        }
    }

    /// Checks only if 24+ hours have elapsed since the last successful check.
    func checkIfStale() async {
        if let lastChecked, Date().timeIntervalSince(lastChecked) < 24 * 60 * 60 {
            return
        }
        await check()
    }

    /// User chose to skip this version. Stored persistently.
    func skipCurrentRelease() {
        guard let version = latestRelease?.version else { return }
        defaults.set(version, forKey: Self.dismissedVersionKey)
    }

    /// `true` when a release strictly newer than the current build is available
    /// AND the user has not skipped it.
    var hasUpdate: Bool {
        guard let release = latestRelease else { return false }
        let current = UpdateService.currentVersion
        guard UpdateService.isUpdateAvailable(current: current, latest: release.version) else {
            return false
        }
        let dismissed = defaults.string(forKey: Self.dismissedVersionKey)
        return dismissed != release.version
    }

    var currentVersion: String { UpdateService.currentVersion }
}
