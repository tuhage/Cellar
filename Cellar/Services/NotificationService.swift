import UserNotifications
import os
import CellarCore

nonisolated final class NotificationService: Sendable {
    static let shared = NotificationService()

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch let error as UNError where error.code == .notificationsNotAllowed {
            Log.notifications.info("Notification permission denied by user")
        } catch {
            Log.notifications.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Send

    func send(title: String, body: String, identifier: String = UUID().uuidString) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()
        do {
            try await center.add(request)
        } catch {
            Log.notifications.error("Failed to add notification '\(identifier, privacy: .public)': \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Convenience

    func notifyUpdatesAvailable(count: Int) async {
        guard count > 0 else { return }
        let noun = count == 1 ? "package" : "packages"
        await send(
            title: "Updates Available",
            body: "\(count) \(noun) can be upgraded.",
            identifier: "updates-available"
        )
    }

    func notifyServiceStopped(name: String) async {
        await send(
            title: "Service Stopped",
            body: "\(name) has been stopped.",
            identifier: "service-stopped-\(name)"
        )
    }

    func notifyCleanupComplete(spaceReclaimed: String) async {
        await send(
            title: "Cleanup Complete",
            body: "\(spaceReclaimed) of disk space reclaimed.",
            identifier: "cleanup-complete"
        )
    }

    func notifyHealthIssues(count: Int) async {
        guard count > 0 else { return }
        let noun = count == 1 ? "issue" : "issues"
        await send(
            title: "Health Check",
            body: "Homebrew doctor found \(count) \(noun).",
            identifier: "health-issues"
        )
    }
}
