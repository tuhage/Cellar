import Foundation
import UserNotifications
import os
import CellarCore

/// Wraps `UNUserNotificationCenter` and surfaces completion notifications
/// for aggregate Homebrew operations. Single-package operations are silent.
@MainActor
final class ActivityNotificationService {
    static let shared = ActivityNotificationService()

    private let center = UNUserNotificationCenter.current()
    private var notifiedIDs = Set<UUID>()

    private init() {}

    /// Requests notification authorization once at app launch. Safe to call
    /// repeatedly; the system handles the deduplication.
    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch let error as UNError where error.code == .notificationsNotAllowed {
            Log.notifications.info("Notification permission denied by user")
        } catch {
            Log.notifications.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Posts a notification when an aggregate operation finishes. Only
    /// `.upgradeAll(count:)` triggers a notification today; other kinds are
    /// silent to avoid spam.
    func notifyCompletion(of op: BrewOperation) {
        // De-duplicate — only fire once per op id
        guard !notifiedIDs.contains(op.id) else { return }
        guard case .upgradeAll(let count) = op.kind else { return }
        notifiedIDs.insert(op.id)

        let content = UNMutableNotificationContent()
        switch op.status {
        case .succeeded:
            content.title = "Upgrade Complete"
            content.body = "\(count) packages upgraded."
        case .failed(let reason):
            content.title = "Upgrade Failed"
            content.body = reason
        case .cancelled:
            content.title = "Upgrade Cancelled"
            content.body = "Cancelled while upgrading \(count) packages."
        case .running:
            return
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "activity.\(op.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        Task {
            do {
                try await center.add(request)
            } catch {
                Log.notifications.error("Failed to add activity notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

/// Forwards notifications to the active foreground app. Without this delegate
/// macOS suppresses any notification fired while Cellar is the active app.
final class ActivityNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
