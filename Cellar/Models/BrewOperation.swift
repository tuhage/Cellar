import Foundation
import CellarCore

/// One tracked Homebrew operation, as shown in the Activity panel.
struct BrewOperation: Identifiable, Equatable {
    let id: UUID
    let kind: Kind
    var status: Status
    let startedAt: Date
    var completedAt: Date?
    /// The user asked to cancel. The operation keeps running until brew has
    /// actually stopped, so its package stays busy until then.
    var isCancelling = false
    /// Started by Cellar itself (such as the daily update check) rather than
    /// the user, so its completion isn't announced.
    let isBackground: Bool
    var log: [String]
    /// The operation's log on disk, under ~/Library/Logs/Cellar.
    var logFileURL: URL?
    /// When brew last printed anything; drives the "no output for a while" hint.
    var lastOutputAt: Date?
    /// Per-package breakdown for batch operations such as Upgrade All.
    var steps: [Step]

    init(
        id: UUID = UUID(),
        kind: Kind,
        status: Status = .running,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        isBackground: Bool = false,
        log: [String] = [],
        lastOutputAt: Date? = nil,
        steps: [Step] = []
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.isBackground = isBackground
        self.log = log
        self.lastOutputAt = lastOutputAt
        self.steps = steps
    }

    /// `true` while the underlying brew process is running.
    var isRunning: Bool {
        status == .running
    }

    var isFailed: Bool {
        if case .failed = status { return true }
        return false
    }

    /// "Installing wget" while running, "Installed wget" once it succeeded.
    var title: String {
        status == .succeeded ? kind.completionTitle : kind.displayTitle
    }

    /// The latest non-empty output line, without brew's `==>` marker, for a
    /// one-line "what is brew doing" hint.
    var lastLogLine: String? {
        guard let line = log.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return nil
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("==>") else { return trimmed }
        return trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Status

extension BrewOperation {

    enum Status: Equatable {
        case running
        case succeeded
        case failed(reason: String)
        case cancelled
    }
}

// MARK: - Target

extension BrewOperation {

    /// What an operation keeps busy. A formula and its service share a
    /// `.package` target, so a service can't be restarted mid-upgrade.
    enum Target: Hashable {
        case package(String)
        case tap(String)
        case brewfile(String)
        case project(String)
        /// Homebrew as a whole: batch upgrades, `brew update`, cleanup.
        case homebrew
    }
}

// MARK: - Kind

extension BrewOperation {

    /// What the operation does. Every case lives here so titles, symbols and
    /// targets are defined in one place.
    enum Kind: Equatable {
        // Packages
        case install(name: String, isCask: Bool)
        case upgrade(name: String, isCask: Bool)
        case reinstall(name: String, isCask: Bool)
        case uninstall(name: String, isCask: Bool)
        case pin(name: String)
        case unpin(name: String)
        case upgradeAll(count: Int)
        // Services
        case serviceStart(name: String)
        case serviceRun(name: String)
        case serviceStop(name: String)
        case serviceRestart(name: String)
        case serviceForceQuit(name: String)
        // Taps
        case tapAdd(name: String)
        case tapRemove(name: String)
        // Brewfiles and projects
        case brewfileInstall(name: String)
        case brewfileExport(name: String)
        case brewfileCleanup(name: String)
        case projectActivate(name: String)
        case projectDeactivate(name: String)
        // Homebrew maintenance
        case brewUpdate
        case cleanup
        case autoremove
        case healthCheck

        /// "Upgrading wget" — shown while the operation runs.
        var displayTitle: String { descriptor.running }

        /// "Upgraded wget" — shown once it succeeded.
        var completionTitle: String { descriptor.done }

        /// SF Symbol for the activity row and notices.
        var symbolName: String { descriptor.symbol }

        var target: Target {
            switch self {
            case .install(let name, _), .upgrade(let name, _), .reinstall(let name, _),
                 .uninstall(let name, _), .pin(let name), .unpin(let name),
                 .serviceStart(let name), .serviceRun(let name), .serviceStop(let name),
                 .serviceRestart(let name), .serviceForceQuit(let name):
                .package(name)
            case .tapAdd(let name), .tapRemove(let name):
                .tap(name)
            case .brewfileInstall(let name), .brewfileExport(let name), .brewfileCleanup(let name):
                .brewfile(name)
            case .projectActivate(let name), .projectDeactivate(let name):
                .project(name)
            case .upgradeAll, .brewUpdate, .cleanup, .autoremove, .healthCheck:
                .homebrew
            }
        }

        private var descriptor: (running: String, done: String, symbol: String) {
            switch self {
            case .install(let name, _): ("Installing \(name)", "Installed \(name)", "arrow.down.circle")
            case .upgrade(let name, _): ("Upgrading \(name)", "Upgraded \(name)", "arrow.up.circle")
            case .reinstall(let name, _): ("Reinstalling \(name)", "Reinstalled \(name)", "arrow.clockwise.circle")
            case .uninstall(let name, _): ("Uninstalling \(name)", "Uninstalled \(name)", "trash")
            case .pin(let name): ("Pinning \(name)", "Pinned \(name)", "pin")
            case .unpin(let name): ("Unpinning \(name)", "Unpinned \(name)", "pin.slash")
            case .upgradeAll(let count):
                ("Upgrading \(Self.packages(count))", "Upgraded \(Self.packages(count))", "arrow.up.circle")
            case .serviceStart(let name): ("Starting \(name)", "Started \(name)", "play.circle")
            case .serviceRun(let name): ("Running \(name) once", "Started \(name) for this session", "play.circle")
            case .serviceStop(let name): ("Stopping \(name)", "Stopped \(name)", "stop.circle")
            case .serviceRestart(let name): ("Restarting \(name)", "Restarted \(name)", "arrow.clockwise.circle")
            case .serviceForceQuit(let name): ("Force quitting \(name)", "Force quit \(name)", "bolt.slash.circle")
            case .tapAdd(let name): ("Adding tap \(name)", "Added tap \(name)", "plus.circle")
            case .tapRemove(let name): ("Removing tap \(name)", "Removed tap \(name)", "minus.circle")
            case .brewfileInstall(let name):
                ("Installing from \(name)", "Installed packages from \(name)", "doc.badge.arrow.up")
            case .brewfileExport(let name): ("Exporting to \(name)", "Exported to \(name)", "square.and.arrow.down")
            case .brewfileCleanup(let name):
                ("Removing packages not in \(name)", "Removed packages not in \(name)", "doc.badge.gearshape")
            case .projectActivate(let name): ("Activating \(name)", "Activated \(name)", "play.fill")
            case .projectDeactivate(let name): ("Deactivating \(name)", "Deactivated \(name)", "stop.fill")
            case .brewUpdate: ("Checking for package updates", "Package list is up to date", "arrow.triangle.2.circlepath")
            case .cleanup: ("Cleaning up Homebrew", "Cleaned up Homebrew", "trash.circle")
            case .autoremove: ("Removing unused dependencies", "Removed unused dependencies", "shippingbox")
            case .healthCheck: ("Running brew doctor", "Finished brew doctor", "stethoscope")
            }
        }

        private static func packages(_ count: Int) -> String {
            "\(count) \(count == 1 ? "package" : "packages")"
        }
    }
}

// MARK: - Steps

extension BrewOperation {

    /// One package inside a batch operation.
    struct Step: Identifiable, Equatable {
        let name: String
        let isCask: Bool
        let currentVersion: String
        let targetVersion: String
        var status: StepStatus = .pending
        var startedAt: Date?
        var completedAt: Date?

        var id: String { Self.id(name: name, isCask: isCask) }

        init(name: String, isCask: Bool, currentVersion: String, targetVersion: String) {
            self.name = name
            self.isCask = isCask
            self.currentVersion = currentVersion
            self.targetVersion = targetVersion
        }

        init(formula: Formula) {
            self.init(
                name: formula.name,
                isCask: false,
                currentVersion: formula.version,
                targetVersion: formula.latestVersion ?? "latest"
            )
        }

        init(cask: Cask) {
            self.init(
                name: cask.token,
                isCask: true,
                currentVersion: cask.installed ?? cask.version,
                targetVersion: cask.version
            )
        }

        static func id(name: String, isCask: Bool) -> String {
            "\(isCask ? "cask" : "formula"):\(name)"
        }
    }

    enum StepStatus: Equatable {
        case pending
        case running
        case succeeded
        case failed(reason: String)
        /// Never ran, or was interrupted, because the batch was cancelled.
        case cancelled

        var isFinished: Bool {
            switch self {
            case .pending, .running: false
            case .succeeded, .failed, .cancelled: true
            }
        }
    }

    var currentStep: Step? {
        steps.first { $0.status == .running }
    }

    var finishedStepCount: Int {
        steps.count(where: { $0.status.isFinished })
    }

    var succeededStepCount: Int {
        steps.count(where: { $0.status == .succeeded })
    }

    var failedSteps: [Step] {
        steps.filter {
            if case .failed = $0.status { return true }
            return false
        }
    }

    /// Position of the running step, 1-based ("3 of 8").
    var currentStepNumber: Int? {
        steps.firstIndex { $0.status == .running }.map { $0 + 1 }
    }
}
