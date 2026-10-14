import Foundation
@preconcurrency import UserNotifications
import os
import CellarCore

/// Posts system notifications for finished operations while Cellar isn't in
/// front. Permission is requested the first time there is something to say.
@MainActor
final class ActivityNotificationService {
    static let shared = ActivityNotificationService()

    /// Settings toggle; notifications are on by default.
    static let enabledKey = "showNotifications"

    private let center = UNUserNotificationCenter.current()

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func post(_ notice: OperationNotice) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.message ?? ""
        content.sound = .default
        let request = UNNotificationRequest(identifier: "activity.\(notice.id.uuidString)", content: content, trigger: nil)

        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            do {
                try await center.add(request)
            } catch {
                Log.notifications.error("Failed to add notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Asks once; afterwards the choice made in System Settings applies.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                Log.notifications.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        default:
            return false
        }
    }
}

/// Shows notifications even while Cellar is the active app — macOS hides
/// them otherwise.
final class ActivityNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
