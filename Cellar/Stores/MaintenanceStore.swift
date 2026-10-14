import Foundation
import Observation
import CellarCore

// MARK: - MaintenanceStore

/// Maintenance schedule, `brew cleanup` / `brew doctor` runs and their
/// report history. Runs are tracked in Activity like any other operation.
@Observable
@MainActor
final class MaintenanceStore {

    // MARK: Data

    var schedule: MaintenanceSchedule = .default
    var reports: [MaintenanceReport] = []

    // MARK: State

    /// Failures to read or write the schedule and reports.
    var errorMessage: String?
    /// Set to show the cleanup preview from anywhere in the app.
    var isCleanupPreviewPresented = false

    // MARK: Dependencies

    let activityStore: ActivityStore
    private let persistence = PersistenceService()
    private let service = BrewService.shared

    private static let scheduleFileName = "maintenance_schedule.json"
    private static let reportsFileName = "maintenance_reports.json"
    private static let maxReports = 100

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
    }

    /// The cleanup or health check that is running, if any.
    var runningTask: BrewOperation? {
        activityStore.runningOperation { $0.kind == .cleanup || $0.kind == .healthCheck }
    }

    var isRunning: Bool { runningTask != nil }

    // MARK: - Persistence

    /// Loads the saved schedule from disk, falling back to the default.
    func loadSettings() {
        schedule = persistence.loadOrDefault(
            MaintenanceSchedule.self,
            from: Self.scheduleFileName,
            default: .default
        )
    }

    /// Persists the current schedule to disk.
    func saveSettings() {
        do {
            try persistence.save(schedule, to: Self.scheduleFileName)
        } catch {
            errorMessage = "Failed to save schedule: \(error.localizedDescription)"
        }
    }

    /// Loads the saved report history from disk.
    func loadReports() {
        reports = persistence.loadOrDefault(
            [MaintenanceReport].self,
            from: Self.reportsFileName,
            default: []
        )
    }

    private func saveReports() {
        reports = Array(reports.prefix(Self.maxReports))
        do {
            try persistence.save(reports, to: Self.reportsFileName)
        } catch {
            errorMessage = "Failed to save reports: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions

    /// Runs `brew cleanup` and records a report. Returns whether it succeeded.
    @discardableResult
    func runCleanup(background: Bool = false) async -> Bool {
        await activityStore.perform(.cleanup, background: background) { activity in
            let output = try await activity.stream(self.service.cleanup()).joined(separator: "\n")
            self.record(.cleanup, summary: Self.cleanupSummary(from: output), output: output)
        } != nil
    }

    /// Runs `brew doctor` and records a report. Returns whether it succeeded.
    @discardableResult
    func runHealthCheck(background: Bool = false) async -> Bool {
        await activityStore.perform(.healthCheck, background: background) { activity in
            let output = try await self.service.doctor()
            activity.log(output: output)
            self.record(.healthCheck, summary: Self.healthCheckSummary(from: output), output: output)
        } != nil
    }

    /// Runs cleanup, then the health check — unless cleanup failed or was
    /// cancelled.
    func runAll() async {
        guard await runCleanup() else { return }
        await runHealthCheck()
    }

    /// Runs any overdue scheduled task in the background.
    func checkSchedule() async {
        guard !isRunning else { return }
        if schedule.isCleanupOverdue {
            await runCleanup(background: true)
        }
        if schedule.isHealthCheckOverdue {
            await runHealthCheck(background: true)
        }
    }

    /// Removes all saved reports.
    func clearReports() {
        reports = []
        saveReports()
    }

    // MARK: - Reports

    private func record(_ type: MaintenanceReportType, summary: String, output: String) {
        let details = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = MaintenanceReport(type: type, summary: summary, details: details.isEmpty ? nil : details)
        switch type {
        case .cleanup: schedule.lastCleanup = report.date
        case .healthCheck: schedule.lastHealthCheck = report.date
        }
        reports.insert(report, at: 0)
        saveSettings()
        saveReports()
    }

    /// Extracts a human-readable summary from `brew cleanup` output.
    private static func cleanupSummary(from output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Nothing to clean up. Homebrew is tidy."
        }

        let lines = trimmed.split(separator: "\n")
        let removedCount = lines.filter { $0.contains("Removing") }.count

        if removedCount > 0 {
            return "Removed \(removedCount) item\(removedCount == 1 ? "" : "s") during cleanup."
        }
        return String(lines.first ?? "Cleanup completed.")
    }

    /// Extracts a human-readable summary from `brew doctor` output.
    private static func healthCheckSummary(from output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains("Your system is ready to brew") {
            return "Your system is ready to brew. No issues found."
        }

        let warningCount = trimmed.components(separatedBy: "Warning:").count - 1
        if warningCount > 0 {
            return "Found \(warningCount) warning\(warningCount == 1 ? "" : "s") during health check."
        }
        return "Health check completed with notes."
    }
}
