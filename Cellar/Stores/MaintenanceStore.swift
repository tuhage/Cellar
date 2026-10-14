import Foundation
import Observation
import CellarCore

// MARK: - MaintenanceStore

/// Maintenance schedule, `brew cleanup` / `brew autoremove` / `brew doctor`
/// runs and their report history, and Homebrew's disk usage. Runs are
/// tracked in Activity like any other operation.
@Observable
@MainActor
final class MaintenanceStore {

    // MARK: Data

    var schedule: MaintenanceSchedule = .default
    var reports: [MaintenanceReport] = []
    let diskUsage = DiskUsageStore()

    // MARK: State

    /// Failures to read or write the schedule and reports.
    var errorMessage: String?
    /// Set to show the autoremove preview from anywhere in the app.
    var isAutoremovePreviewPresented = false
    /// Set to show the cleanup preview from anywhere in the app.
    var isCleanupPreviewPresented = false {
        didSet {
            if !isCleanupPreviewPresented { checksHealthAfterCleanup = false }
        }
    }
    /// Run All shows the cleanup preview too; confirming it then also runs
    /// the health check. Reset whenever the preview closes.
    private(set) var checksHealthAfterCleanup = false

    // MARK: Dependencies

    let activityStore: ActivityStore
    private let persistence = PersistenceService()
    private let service = BrewService.shared

    private static let scheduleFileName = "maintenance_schedule.json"
    private static let reportsFileName = "maintenance_reports.json"
    private static let maxReports = 100
    private static let kinds: [BrewOperation.Kind] = [.cleanup, .autoremove, .healthCheck]

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
    }

    /// The cleanup, autoremove or health check that is running, if any.
    var runningTask: BrewOperation? {
        activityStore.runningOperation { Self.kinds.contains($0.kind) }
    }

    var isRunning: Bool { runningTask != nil }

    /// The most recent `brew doctor` run.
    var latestHealthCheck: MaintenanceReport? {
        reports.first { $0.type == .healthCheck }
    }

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

    /// Shows the cleanup preview; confirming it runs cleanup and then the
    /// health check.
    func previewRunAll() {
        checksHealthAfterCleanup = true
        isCleanupPreviewPresented = true
    }

    /// Runs `brew cleanup` and records a report. Returns whether it succeeded.
    /// The user starts it from the cleanup preview; only scheduled runs
    /// (`background`) skip it.
    @discardableResult
    func runCleanup(depth: CleanupDepth = .standard, background: Bool = false) async -> Bool {
        let succeeded = await activityStore.perform(.cleanup, background: background) { activity in
            let output = try await activity.stream(self.service.cleanup(depth)).joined(separator: "\n")
            self.record(.cleanup, summary: CleanupPlan.parse(output).resultSummary, output: output)
        } != nil
        await diskUsage.reloadIfLoaded()
        return succeeded
    }

    /// Runs `brew autoremove` and records a report. Returns whether it succeeded.
    @discardableResult
    func runAutoremove() async -> Bool {
        let succeeded = await activityStore.perform(.autoremove) { activity in
            let output = try await activity.stream(self.service.autoremove()).joined(separator: "\n")
            self.record(.autoremove, summary: CleanupPlan.parse(output).autoremoveSummary, output: output)
        } != nil
        await diskUsage.reloadIfLoaded()
        return succeeded
    }

    /// Runs `brew doctor` and records a report. Returns whether it succeeded.
    @discardableResult
    func runHealthCheck(background: Bool = false) async -> Bool {
        await activityStore.perform(.healthCheck, background: background) { activity in
            let output = try await self.service.doctor()
            activity.log(output: output)
            self.record(.healthCheck, summary: DoctorReport(output: output).summary, output: output)
        } != nil
    }

    /// Runs cleanup, then the health check — unless cleanup failed or was
    /// cancelled.
    func runAll(depth: CleanupDepth = .standard) async {
        guard await runCleanup(depth: depth) else { return }
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
        case .autoremove: break
        }
        reports.insert(report, at: 0)
        saveSettings()
        saveReports()
    }
}
