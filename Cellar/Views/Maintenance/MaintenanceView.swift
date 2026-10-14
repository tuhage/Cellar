import SwiftUI
import CellarCore

struct MaintenanceView: View {
    @Environment(MaintenanceStore.self) private var store

    @State private var searchText = ""
    @State private var isAutoremovePreviewPresented = false
    @State private var isClearReportsConfirmationPresented = false

    /// Any Homebrew-wide operation (Upgrade All, `brew update`, maintenance)
    /// blocks the maintenance tasks.
    private var isBusy: Bool {
        store.activityStore.isActive(.homebrew)
    }

    private var filteredReports: [MaintenanceReport] {
        guard !searchText.isEmpty else { return store.reports }
        return store.reports.filter {
            $0.type.title.localizedCaseInsensitiveContains(searchText)
            || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Form {
            tasksSection
            healthSection
            DiskUsageSection(store: store.diskUsage)
            scheduleSection
            reportsSection
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: Spacing.none) {
                if let task = store.runningTask {
                    RunningOperationBar(operation: task)
                }
                if let errorMessage = store.errorMessage {
                    NoticeBanner(tint: .red, systemImage: "exclamationmark.triangle.fill", title: errorMessage) {
                        Button("Dismiss") { store.errorMessage = nil }
                    }
                }
            }
        }
        .loadErrorBanner(for: store.diskUsage) { await reloadDiskUsage() }
        .navigationTitle("Maintenance")
        .dataFreshness(store.diskUsage.lastUpdated)
        .maintenanceSearchable(text: $searchText, enabled: !store.reports.isEmpty)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.diskUsage.isLoading) {
                    await reloadDiskUsage()
                }
            }
        }
        .focusedSceneValue(\.pageRefresh, AsyncAction { await reloadDiskUsage() })
        .task { await store.diskUsage.load() }
        .sheet(isPresented: $isAutoremovePreviewPresented) {
            AutoremovePreviewSheet()
        }
        .confirmationDialog(
            "Clear all maintenance reports?",
            isPresented: $isClearReportsConfirmationPresented
        ) {
            Button("Clear Reports", role: .destructive) {
                store.clearReports()
            }
        } message: {
            Text("This removes \(store.reports.count) \(store.reports.count == 1 ? "report" : "reports"). Your schedule isn’t affected.")
        }
    }

    private func reloadDiskUsage() async {
        await store.diskUsage.load(force: true)
    }

    // MARK: - Tasks

    private var tasksSection: some View {
        Section {
            TaskRow(
                title: "Clean Up",
                description: "Remove old versions, outdated downloads and logs. You’ll see what will be removed first.",
                systemImage: "trash",
                buttonTitle: "Clean Up\u{2026}",
                isDisabled: isBusy
            ) {
                store.isCleanupPreviewPresented = true
            }

            TaskRow(
                title: "Remove Unused Dependencies",
                description: "Uninstall formulae that were installed only as dependencies and are no longer needed.",
                systemImage: "shippingbox",
                buttonTitle: "Remove\u{2026}",
                isDisabled: isBusy
            ) {
                isAutoremovePreviewPresented = true
            }

            TaskRow(
                title: "Check Health",
                description: "Run brew doctor to find problems with your Homebrew setup.",
                systemImage: "stethoscope",
                buttonTitle: "Check Health",
                isDisabled: isBusy
            ) {
                Task { await store.runHealthCheck() }
            }

            TaskRow(
                title: "Run All",
                description: "Clean up, then check health. Stops if the cleanup fails or is cancelled.",
                systemImage: "play",
                buttonTitle: "Run All\u{2026}",
                isDisabled: isBusy
            ) {
                store.previewRunAll()
            }
        } header: {
            Text("Tasks")
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        Section {
            if let report = store.latestHealthCheck {
                DoctorFindingList(report: DoctorReport(output: report.details ?? ""))
            } else {
                Text("Check health to see whether brew doctor finds any problems.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Health")
                Spacer()
                if let date = store.latestHealthCheck?.date {
                    Text("Checked \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            ScheduleRow(
                title: "Automatic Cleanup",
                frequency: store.schedule.cleanupFrequency,
                status: store.schedule.cleanupStatus(),
                lastRun: store.schedule.lastCleanup
            )
            ScheduleRow(
                title: "Automatic Health Check",
                frequency: store.schedule.healthCheckFrequency,
                status: store.schedule.healthCheckStatus(),
                lastRun: store.schedule.lastHealthCheck
            )
            SettingsLink {
                Text("Change in Settings\u{2026}")
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text("Scheduled tasks run only while Cellar is open; it checks for due tasks once an hour. Scheduled cleanups run without asking and remove old versions, outdated downloads, logs and unused dependencies.")
        }
    }

    // MARK: - Reports

    private var reportsSection: some View {
        Section {
            if store.reports.isEmpty {
                EmptyStateView(
                    title: "No Reports Yet",
                    systemImage: "doc.text",
                    description: "Cleanups, removed dependencies and health checks are recorded here."
                )
            } else if filteredReports.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "magnifyingglass",
                    description: "No reports match “\(searchText)”."
                )
            } else {
                ForEach(filteredReports) { report in
                    MaintenanceReportRow(report: report)
                }
            }
        } header: {
            HStack {
                Text("Reports")
                Spacer()
                if !store.reports.isEmpty {
                    Button("Clear Reports\u{2026}") {
                        isClearReportsConfirmationPresented = true
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let title: String
    let description: String
    let systemImage: String
    let buttonTitle: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        LabeledContent {
            Button(buttonTitle, action: action)
                .disabled(isDisabled)
        } label: {
            Label {
                Text(title)
                Text(description)
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}

// MARK: - Schedule Row

private struct ScheduleRow: View {
    let title: String
    let frequency: MaintenanceFrequency
    let status: MaintenanceSchedule.Status
    let lastRun: Date?

    var body: some View {
        LabeledContent {
            Text(statusText)
                .foregroundStyle(status == .overdue ? .orange : .secondary)
        } label: {
            Text(title)
            Text(lastRun.map { "Last run \($0.formatted(.relative(presentation: .named)))" } ?? "Never run")
        }
    }

    private var statusText: String {
        switch status {
        case .off: "Off"
        case .dueNow: "\(frequency.title) · Due now"
        case .overdue: "\(frequency.title) · Overdue"
        case .scheduled(let date): "\(frequency.title) · Next \(date.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

private extension View {
    @ViewBuilder
    func maintenanceSearchable(text: Binding<String>, enabled: Bool) -> some View {
        if enabled {
            searchable(text: text, placement: .toolbar, prompt: "Search reports")
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MaintenanceView()
    }
    .environment(AppStores())
    .frame(width: 640, height: 900)
}
