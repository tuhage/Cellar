import SwiftUI

struct MaintenanceView: View {
    @Environment(MaintenanceStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ZStack {
            Form {
                Section {
                    Toggle("Auto Cleanup", isOn: $store.schedule.autoCleanup)
                        .onChange(of: store.schedule.autoCleanup) { self.store.saveSettings() }

                    if store.schedule.autoCleanup {
                        Picker("Cleanup Frequency", selection: $store.schedule.cleanupFrequency) {
                            ForEach(MaintenanceFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .onChange(of: store.schedule.cleanupFrequency) { self.store.saveSettings() }
                    }

                    if let lastCleanup = store.schedule.lastCleanup {
                        LabeledContent("Last Cleanup", value: lastCleanup.formatted(date: .abbreviated, time: .shortened))
                    }

                    Toggle("Auto Health Check", isOn: $store.schedule.autoHealthCheck)
                        .onChange(of: store.schedule.autoHealthCheck) { self.store.saveSettings() }

                    if store.schedule.autoHealthCheck {
                        Picker("Health Check Frequency", selection: $store.schedule.healthCheckFrequency) {
                            ForEach(MaintenanceFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .onChange(of: store.schedule.healthCheckFrequency) { self.store.saveSettings() }
                    }

                    if let lastHealthCheck = store.schedule.lastHealthCheck {
                        LabeledContent("Last Health Check", value: lastHealthCheck.formatted(date: .abbreviated, time: .shortened))
                    }
                } header: {
                    Text("Schedule")
                }

                actionsSection
                reportsSection
            }
            .formStyle(.grouped)

            if store.isRunning {
                runningOverlay
            }
        }
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.runAll() }
                } label: {
                    Label("Run All", systemImage: "play.fill")
                }
                .disabled(store.isRunning)
            }
        }
        .task {
            store.loadSettings()
            store.loadReports()
            await store.checkSchedule()
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            HStack {
                Button {
                    Task { await store.runCleanup() }
                } label: {
                    Label("Run Cleanup", systemImage: "trash")
                }
                .disabled(store.isRunning)

                Spacer()

                Button {
                    Task { await store.runHealthCheck() }
                } label: {
                    Label("Run Health Check", systemImage: "heart.text.square")
                }
                .disabled(store.isRunning)
            }

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        } header: {
            Text("Run Now")
        }
    }

    // MARK: - Reports Section

    private var reportsSection: some View {
        Section {
            if store.reports.isEmpty {
                ContentUnavailableView(
                    "No Reports",
                    systemImage: "doc.text",
                    description: Text("Maintenance reports will appear here after tasks run.")
                )
                .frame(minHeight: 120)
            } else {
                ForEach(store.reports) { report in
                    MaintenanceReportRow(report: report)
                }
            }
        } header: {
            HStack {
                Text("Reports")
                Spacer()
                if !store.reports.isEmpty {
                    Button("Clear Reports", role: .destructive) {
                        store.clearReports()
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Running Overlay

    private var runningOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                if let action = store.currentAction {
                    Text(action)
                        .font(.headline)
                }

                Text("Please wait while Homebrew completes the task.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - MaintenanceReportRow

private struct MaintenanceReportRow: View {
    let report: MaintenanceReport

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: report.type.icon)
                    .font(.title2)
                    .foregroundStyle(report.type == .cleanup ? .orange : .green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(report.type.title)
                        .fontWeight(.medium)

                    Text(report.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)

                    Text(report.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if report.details != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isExpanded, let details = report.details {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .padding(.leading, 36)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MaintenanceView()
    }
    .environment(MaintenanceStore())
    .frame(width: 600, height: 700)
}
