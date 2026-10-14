import AppKit
import Observation
import SwiftUI

/// Announces finished operations: a notice in the window while Cellar is in
/// front, a system notification otherwise. Operations Cellar started on its
/// own (scheduled cleanup, the daily update check) stay silent.
@Observable
@MainActor
final class NoticeStore {
    /// The notice shown in the main window, if any.
    private(set) var current: OperationNotice?

    private var dismissTask: Task<Void, Never>?
    private var isHovering = false
    private static let displayDuration: Duration = .seconds(6)

    func announce(_ operation: BrewOperation) {
        guard !operation.isBackground, !operation.isRunning else { return }
        let notice = OperationNotice(operation: operation)
        guard NSApplication.shared.isMainWindowInFront else {
            ActivityNotificationService.shared.post(notice)
            return
        }
        current = notice
        AccessibilityNotification.Announcement(notice.spokenText).post()
        scheduleDismissal()
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }

    /// Hovering keeps the notice up so it can be read and acted on.
    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            dismissTask?.cancel()
        } else {
            scheduleDismissal()
        }
    }

    private func scheduleDismissal() {
        dismissTask?.cancel()
        guard let current, !current.staysUntilDismissed, !isHovering else { return }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled, self?.current?.id == current.id else { return }
            self?.current = nil
        }
    }
}
