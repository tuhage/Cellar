import SwiftUI
import CellarCore

struct MaintenanceView: View {
    @Environment(MaintenanceStore.self) private var store

    @State private var searchText = ""

    private var filteredReports: [MaintenanceReport] {
        guard !searchText.isEmpty else { return store.reports }
        return store.reports.filter {
            $0.type.title.localizedCaseInsensitiveContains(searchText)
            || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

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

                    if store.schedule.autoCleanup,
                       let nextCleanup = nextRun(after: store.schedule.lastCleanup, frequency: store.schedule.cleanupFrequency) {
                        LabeledContent("Next Cleanup", value: nextCleanup.formatted(date: .abbreviated, time: .shortened))
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
                    if store.schedule.autoHealthCheck,
                       let nextHealthCheck = nextRun(after: store.schedule.lastHealthCheck, frequency: store.schedule.healthCheckFrequency) {
                        LabeledContent("Next Health Check", value: nextHealthCheck.formatted(date: .abbreviated, time: .shortened))
                    }
                } header: {
                    Label("Automation", systemImage: "calendar.badge.clock")
                }

                actionsSection
                reportsSection
            }
            .formStyle(.grouped)

            if store.isLoading {
                runningOverlay
            }
        }
        .navigationTitle("Maintenance")
        .maintenanceSearchable(text: $searchText, enabled: !store.reports.isEmpty)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            HStack {
                Button {
                    Task { await store.runCleanup() }
                } label: {
                    Label("Run Cleanup", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoading)

                Button {
                    Task { await store.runHealthCheck() }
                } label: {
                    Label("Run Health Check", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoading)

                Button {
                    Task { await store.runAll() }
                } label: {
                    Label("Run All", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoading)
            }

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        } header: {
            Label("Run Now", systemImage: "play.circle")
        }
    }

    // MARK: - Reports Section

    private var reportsSection: some View {
        Section {
            if store.reports.isEmpty {
                HStack(spacing: Spacing.sectionContent) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundStyle(.tertiary)

                    VStack(alignment: .leading, spacing: Spacing.textPair) {
                        Text("No Reports Yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Run a cleanup or health check to generate a report.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.item)
            } else if filteredReports.isEmpty {
                Text("No reports matching \"\(searchText)\"")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.item)
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
                    Button("Clear Reports", role: .destructive) {
                        store.clearReports()
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func nextRun(after lastRun: Date?, frequency: MaintenanceFrequency) -> Date? {
        Calendar.current.date(
            byAdding: frequency.calendarComponent,
            value: 1,
            to: lastRun ?? .now
        )
    }

    // MARK: - Running Overlay

    private var runningOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Spacing.cardPadding) {
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
            .padding(Spacing.section)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.extraLarge))
            .shadow(color: Shadow.elevatedColor, radius: Shadow.elevatedBlur, y: Shadow.elevatedY)
        }
    }
}

// MARK: - MaintenanceReportRow

private struct MaintenanceReportRow: View {
    let report: MaintenanceReport

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            HStack(alignment: .top, spacing: Spacing.row) {
                let iconColor: Color = report.type == .cleanup ? .orange : .green
                Image(systemName: report.type.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: IconSize.smallIcon, height: IconSize.smallIcon)
                    .background(iconColor.opacity(Opacity.iconBackground), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(report.type.title)
                            .fontWeight(.medium)

                        Spacer()

                        Text(report.date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text(report.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                if report.details != nil {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard report.details != nil else { return }
                withAnimation(AnimationToken.snap) {
                    isExpanded.toggle()
                }
            }

            if isExpanded, let details = report.details {
                Text(details)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(Spacing.item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(cornerRadius: CornerRadius.small)
                    .padding(.leading, 38)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, Spacing.compact)
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
    .environment(MaintenanceStore())
    .frame(width: 600, height: 700)
}
