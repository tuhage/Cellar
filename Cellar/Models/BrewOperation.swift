import Foundation
import CellarCore

/// Represents a single tracked Homebrew operation in the activity panel.
struct BrewOperation: Identifiable, Equatable {
    let id: UUID
    let kind: Kind
    var status: Status
    let startedAt: Date
    var completedAt: Date?
    var log: [String]
    /// The operation's log on disk, under ~/Library/Logs/Cellar.
    var logFileURL: URL?
    /// When brew last printed anything; drives the "no output for a while" hint.
    var lastOutputAt: Date?
    var error: String?
    /// Per-package breakdown for batch operations such as Upgrade All.
    var steps: [Step]

    init(
        id: UUID = UUID(),
        kind: Kind,
        status: Status = .running,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        log: [String] = [],
        lastOutputAt: Date? = nil,
        error: String? = nil,
        steps: [Step] = []
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.log = log
        self.lastOutputAt = lastOutputAt
        self.error = error
        self.steps = steps
    }
}

extension BrewOperation {

    /// What the operation is doing. The associated values carry just enough
    /// context for the UI label and `isActive(target:)` lookups.
    enum Kind: Equatable {
        case install(name: String, isCask: Bool)
        case upgrade(name: String, isCask: Bool)
        case uninstall(name: String, isCask: Bool)
        case upgradeAll(count: Int)
        case serviceStart(name: String)
        case serviceStop(name: String)
        case serviceRestart(name: String)
        case serviceKill(name: String)
        case tapAdd(url: String)
        case tapRemove(name: String)
        case brewfileInstall
        case brewfileCleanup
        case cleanup
        case healthCheck
        case brewUpdate
        case projectActivate(name: String)
        case projectDeactivate(name: String)

        /// Human-readable label for the activity row.
        var displayTitle: String {
            switch self {
            case .install(let name, _): "Installing \(name)"
            case .upgrade(let name, _): "Upgrading \(name)"
            case .uninstall(let name, _): "Uninstalling \(name)"
            case .upgradeAll(let count): "Upgrading \(count) \(count == 1 ? "package" : "packages")"
            case .serviceStart(let name): "Starting \(name)"
            case .serviceStop(let name): "Stopping \(name)"
            case .serviceRestart(let name): "Restarting \(name)"
            case .serviceKill(let name): "Force stopping \(name)"
            case .tapAdd(let url): "Adding tap \(url)"
            case .tapRemove(let name): "Removing tap \(name)"
            case .brewfileInstall: "Installing from Brewfile"
            case .brewfileCleanup: "Cleaning up Brewfile"
            case .cleanup: "Homebrew cleanup"
            case .healthCheck: "Homebrew doctor"
            case .brewUpdate: "Checking for updates"
            case .projectActivate(let name): "Activating \(name)"
            case .projectDeactivate(let name): "Deactivating \(name)"
            }
        }

        /// Human-readable completion copy used by transient success feedback.
        var completionTitle: String {
            switch self {
            case .install(let name, _): "Installed \(name)"
            case .upgrade(let name, _): "Upgraded \(name)"
            case .uninstall(let name, _): "Uninstalled \(name)"
            case .upgradeAll(let count): "Upgraded \(count) \(count == 1 ? "package" : "packages")"
            case .serviceStart(let name): "Started \(name)"
            case .serviceStop(let name): "Stopped \(name)"
            case .serviceRestart(let name): "Restarted \(name)"
            case .serviceKill(let name): "Force stopped \(name)"
            case .tapAdd(let url): "Added tap \(url)"
            case .tapRemove(let name): "Removed tap \(name)"
            case .brewfileInstall: "Installed Brewfile packages"
            case .brewfileCleanup: "Cleaned up Brewfile"
            case .cleanup: "Homebrew cleanup completed"
            case .healthCheck: "Homebrew doctor completed"
            case .brewUpdate: "Package list is up to date"
            case .projectActivate(let name): "Activated \(name)"
            case .projectDeactivate(let name): "Deactivated \(name)"
            }
        }

        /// SF Symbol shown on the leading edge of the activity row.
        var symbolName: String {
            switch self {
            case .install: "arrow.down.circle"
            case .upgrade, .upgradeAll: "arrow.up.circle"
            case .uninstall: "trash"
            case .serviceStart: "play.circle"
            case .serviceStop: "stop.circle"
            case .serviceRestart: "arrow.clockwise.circle"
            case .serviceKill: "bolt.slash.circle"
            case .tapAdd: "plus.circle"
            case .tapRemove: "minus.circle"
            case .brewfileInstall: "doc.badge.arrow.up"
            case .brewfileCleanup: "doc.badge.gearshape"
            case .cleanup: "trash.circle"
            case .healthCheck: "stethoscope"
            case .brewUpdate: "arrow.triangle.2.circlepath"
            case .projectActivate: "play.fill"
            case .projectDeactivate: "stop.fill"
            }
        }

        /// Name targeted by this operation (for `isActive(target:)` lookups).
        /// Returns `nil` for kinds that aren't keyed by a single package name.
        var targetName: String? {
            switch self {
            case .install(let name, _),
                 .upgrade(let name, _),
                 .uninstall(let name, _),
                 .serviceStart(let name),
                 .serviceStop(let name),
                 .serviceRestart(let name),
                 .serviceKill(let name),
                 .tapRemove(let name),
                 .projectActivate(let name),
                 .projectDeactivate(let name):
                name
            case .tapAdd(let url):
                url
            case .upgradeAll, .brewfileInstall, .brewfileCleanup, .cleanup, .healthCheck, .brewUpdate:
                nil
            }
        }

        /// Whether the operation changes packages and is worth a log file.
        /// Quick service toggles and read-only checks are left out.
        var isLoggedToDisk: Bool {
            switch self {
            case .install, .upgrade, .uninstall, .upgradeAll, .tapAdd, .tapRemove,
                 .brewfileInstall, .brewfileCleanup, .cleanup, .brewUpdate:
                true
            case .serviceStart, .serviceStop, .serviceRestart, .serviceKill,
                 .healthCheck, .projectActivate, .projectDeactivate:
                false
            }
        }
    }

    enum Status: Equatable {
        case running
        case succeeded
        case failed(reason: String)
        case cancelled
    }

    /// `true` while the underlying brew process is running.
    var isRunning: Bool {
        if case .running = status { return true }
        return false
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
