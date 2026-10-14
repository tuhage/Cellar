import Foundation
import Testing
@testable import CellarCore

@Suite("Maintenance Schedule")
struct MaintenanceScheduleTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    @Test("maintenanceSchedule_status_disabledIsOff")
    func maintenanceSchedule_status_disabledIsOff() {
        let status = MaintenanceSchedule.status(isEnabled: false, lastRun: nil, frequency: .weekly, now: now)

        #expect(status == .off)
        #expect(!status.isDue)
    }

    @Test("maintenanceSchedule_status_neverRunIsDueNow")
    func maintenanceSchedule_status_neverRunIsDueNow() {
        let schedule = MaintenanceSchedule(autoCleanup: true)

        #expect(schedule.cleanupStatus(now: now) == .dueNow)
        #expect(schedule.isCleanupOverdue)
    }

    @Test("maintenanceSchedule_status_pastDueIsOverdue")
    func maintenanceSchedule_status_pastDueIsOverdue() {
        let schedule = MaintenanceSchedule(autoHealthCheck: true, healthCheckFrequency: .daily, lastHealthCheck: daysAgo(2))

        #expect(schedule.healthCheckStatus(now: now) == .overdue)
    }

    @Test("maintenanceSchedule_status_recentRunIsScheduled")
    func maintenanceSchedule_status_recentRunIsScheduled() {
        let lastRun = daysAgo(3)
        let schedule = MaintenanceSchedule(autoCleanup: true, cleanupFrequency: .weekly, lastCleanup: lastRun)
        let expected = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: lastRun)!

        #expect(schedule.cleanupStatus(now: now) == .scheduled(expected))
    }

    @Test("maintenanceSchedule_nextRun_neverRunHasNoDate")
    func maintenanceSchedule_nextRun_neverRunHasNoDate() {
        #expect(MaintenanceSchedule.nextRun(after: nil, frequency: .monthly) == nil)
    }
}
