import Foundation
import Observation
import CellarCore

// MARK: - MaintenanceStore

/// Manages maintenance schedule settings, runs brew cleanup and doctor tasks,
/// and persists a history of maintenance reports.
@Observable
@MainActor
final class MaintenanceStore {

    // MARK: Data

    var schedule: MaintenanceSchedule = .default
    var reports: [MaintenanceReport] = []

    // MARK: State

    var isRunning = false
    var errorMessage: String?
    var currentAction: String?

    // MARK: Dependencies

    private let persistence = PersistenceService()
    private let service = BrewService()

    private static let scheduleFileName = "maintenance_schedule.json"
    private static let reportsFileName = "maintenance_reports.json"

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

    /// Persists the current report history to disk.
    private func saveReports() {
        do {
            try persistence.save(reports, to: Self.reportsFileName)
        } catch {
            errorMessage = "Failed to save reports: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions

    /// Runs `brew cleanup` and records a report.
    func runCleanup() async {
        isRunning = true
        currentAction = "Running cleanup\u{2026}"
        errorMessage = nil

        do {
            var output = ""
            let stream = service.cleanup()
            for try await line in stream {
                output += line
            }

            let summary = cleanupSummary(from: output)
            let report = MaintenanceReport(
                type: .cleanup,
                summary: summary,
                details: output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            schedule.lastCleanup = report.date
            reports.insert(report, at: 0)

            saveSettings()
            saveReports()
        } catch {
            errorMessage = "Cleanup failed: \(error.localizedDescription)"
        }

        isRunning = false
        currentAction = nil
    }

    /// Runs `brew doctor` and records a report.
    func runHealthCheck() async {
        isRunning = true
        currentAction = "Running health check\u{2026}"
        errorMessage = nil

        do {
            let output = try await service.doctor()

            let summary = healthCheckSummary(from: output)
            let report = MaintenanceReport(
                type: .healthCheck,
                summary: summary,
                details: output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            schedule.lastHealthCheck = report.date
            reports.insert(report, at: 0)

            saveSettings()
            saveReports()
        } catch {
            errorMessage = "Health check failed: \(error.localizedDescription)"
        }

        isRunning = false
        currentAction = nil
    }

    /// Runs both cleanup and health check sequentially.
    func runAll() async {
        await runCleanup()
        guard errorMessage == nil else { return }
        await runHealthCheck()
    }

    /// Checks if any scheduled task is overdue and runs it.
    func checkSchedule() async {
        if schedule.isCleanupOverdue {
            await runCleanup()
        }
        if schedule.isHealthCheckOverdue {
            await runHealthCheck()
        }
    }

    /// Removes all saved reports.
    func clearReports() {
        reports = []
        saveReports()
    }

    // MARK: - Summarization

    /// Extracts a human-readable summary from `brew cleanup` output.
    private func cleanupSummary(from output: String) -> String {
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
    private func healthCheckSummary(from output: String) -> String {
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
