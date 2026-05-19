import Foundation

/// Represents a single tracked Homebrew operation in the activity panel.
struct BrewOperation: Identifiable, Equatable {
    let id: UUID
    let kind: Kind
    var status: Status
    let startedAt: Date
    var completedAt: Date?
    var log: [String]
    var error: String?

    init(
        id: UUID = UUID(),
        kind: Kind,
        status: Status = .running,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        log: [String] = [],
        error: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.log = log
        self.error = error
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
        case projectActivate(name: String)
        case projectDeactivate(name: String)

        /// Human-readable label for the activity row.
        var displayTitle: String {
            switch self {
            case .install(let name, _): "Installing \(name)"
            case .upgrade(let name, _): "Upgrading \(name)"
            case .uninstall(let name, _): "Uninstalling \(name)"
            case .upgradeAll(let count): "Upgrading \(count) packages"
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
            case .projectActivate(let name): "Activating \(name)"
            case .projectDeactivate(let name): "Deactivating \(name)"
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
            case .upgradeAll, .brewfileInstall, .brewfileCleanup, .cleanup, .healthCheck:
                nil
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
