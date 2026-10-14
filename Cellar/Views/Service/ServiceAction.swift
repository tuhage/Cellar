import Foundation
import CellarCore

/// Something the user can do with a service. The list's context menu and
/// the inspector offer the same actions, so they are defined once here.
enum ServiceAction: CaseIterable, Identifiable {
    case start
    case runOnce
    case stop
    case stopKeepingRegistration
    case restart
    case forceQuit
    case uninstall

    var id: Self { self }

    /// Reversible actions, shown first.
    static let lifecycle: [ServiceAction] = [.start, .runOnce, .stop, .stopKeepingRegistration, .restart]
    /// Actions that need confirmation.
    static let destructive: [ServiceAction] = [.forceQuit, .uninstall]

    var isDestructive: Bool {
        Self.destructive.contains(self)
    }

    func title(for service: BrewServiceItem) -> String {
        switch self {
        case .start: "Start"
        case .runOnce: "Run Once"
        case .stop: "Stop"
        case .stopKeepingRegistration: service.requiresRoot ? "Stop (Keep at Boot)" : "Stop (Keep at Login)"
        case .restart: "Restart"
        case .forceQuit: "Force Quit\u{2026}"
        case .uninstall: "Uninstall\u{2026}"
        }
    }

    /// "Force quit" in the confirmation "Force quit redis?".
    var confirmationVerb: String {
        self == .forceQuit ? "Force quit" : "Uninstall"
    }

    var systemImage: String {
        switch self {
        case .start: "play.circle"
        case .runOnce: "play"
        case .stop: "stop.circle"
        case .stopKeepingRegistration: "pause.circle"
        case .restart: "arrow.clockwise.circle"
        case .forceQuit: "bolt.slash.circle"
        case .uninstall: "trash"
        }
    }

    func help(for service: BrewServiceItem) -> String {
        let startup = service.requiresRoot ? "at boot" : "at login"
        return switch self {
        case .start: "Start now and \(startup)"
        case .runOnce: "Start now without starting \(startup)"
        case .stop: "Stop and don’t start \(startup)"
        case .stopKeepingRegistration: "Stop now but still start \(startup)"
        case .restart: "Stop and start again"
        case .forceQuit: "Kill the process immediately"
        case .uninstall: "Stop the service and remove the formula"
        }
    }

    /// Whether the action makes sense in the service's current state.
    func isAvailable(for service: BrewServiceItem) -> Bool {
        switch self {
        case .start, .runOnce: !service.isRunning
        // A loaded service that isn't running (failed, scheduled) can still be unloaded or restarted.
        case .stop, .restart: service.status != .none
        case .stopKeepingRegistration, .forceQuit: service.isRunning
        case .uninstall: true
        }
    }

    @MainActor
    func perform(on service: BrewServiceItem, store: ServiceStore) async {
        switch self {
        case .start: await store.start(service)
        case .runOnce: await store.runOnce(service)
        case .stop: await store.stop(service)
        case .stopKeepingRegistration: await store.stop(service, keepRegistered: true)
        case .restart: await store.restart(service)
        case .forceQuit: await store.forceQuit(service)
        case .uninstall: await store.uninstall(service)
        }
    }
}

/// A destructive action waiting for the user to confirm it.
struct PendingServiceAction: Identifiable {
    let action: ServiceAction
    let service: BrewServiceItem

    var id: String { "\(action)-\(service.id)" }
}
