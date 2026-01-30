import SwiftUI
import CellarCore

struct HealthCheckView: View {
    @State private var store = HealthStore()
    @State private var copiedCheckID: UUID?

    var body: some View {
        Group {
            if let stream = store.actionStream {
                actionOutputView(
                    title: store.actionTitle ?? "Running",
                    stream: stream
                )
            } else if store.isLoading {
                LoadingView(message: "Running diagnostics\u{2026}")
            } else if let errorMessage = store.errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await store.runDiagnostics() }
                }
            } else if store.checks.isEmpty {
                EmptyStateView(
                    title: "No Diagnostics Run",
                    systemImage: "heart.text.square",
                    description: "Click \"Run Diagnostics\" to check your Homebrew installation."
                )
            } else {
                healthContent
            }
        }
        .navigationTitle("Health")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.runDiagnostics() }
                } label: {
                    Label("Run Diagnostics", systemImage: "stethoscope")
                }
                .disabled(store.isLoading || store.isPerformingAction)
            }
        }
        .task {
            if store.checks.isEmpty {
                await store.runDiagnostics()
            }
        }
    }

    // MARK: - Content

    private var healthContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                healthStatusBanner
                quickActionsSection
                issuesSections
            }
            .padding(24)
        }
    }

    // MARK: - Status Banner

    private var healthStatusBanner: some View {
        let bannerColor: Color = store.isHealthy ? .green : .yellow

        return HStack(spacing: 12) {
            Image(systemName: store.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(bannerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.isHealthy ? "System Healthy" : "\(store.issueCount) Issue\(store.issueCount == 1 ? "" : "s") Found")
                    .font(.headline)

                if store.isHealthy {
                    Text("Your Homebrew installation is in good shape.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(severityBreakdown)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(bannerColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var severityBreakdown: String {
        var parts: [String] = []
        if store.criticalCount > 0 {
            parts.append("\(store.criticalCount) critical")
        }
        if store.warningCount > 0 {
            parts.append("\(store.warningCount) warning\(store.warningCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " \u{b7} ")
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Quick Actions", systemImage: "bolt.fill", color: .blue)

            HStack(spacing: 12) {
                quickActionButton(
                    title: "Cleanup",
                    systemImage: "trash.circle.fill",
                    color: .red
                ) {
                    store.runCleanup()
                }

                quickActionButton(
                    title: "Upgrade All",
                    systemImage: "arrow.up.circle.fill",
                    color: .orange
                ) {
                    store.runUpgradeAll()
                }
            }
        }
    }

    private func quickActionButton(
        title: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .controlSize(.large)
        .disabled(store.isPerformingAction)
    }

    // MARK: - Issues Sections

    private var issuesSections: some View {
        ForEach(store.checksBySeverity, id: \.severity) { group in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(severitySectionTitle(group.severity), systemImage: group.severity.icon)
                        .foregroundStyle(group.severity.color)
                        .font(.headline)
                    Spacer()
                    Text("\(group.checks.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(group.checks) { check in
                            HealthCheckRow(
                                check: check,
                                isCopied: copiedCheckID == check.id,
                                onFix: { runFix(for: check) }
                            )

                            if check.id != group.checks.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action Output

    private func actionOutputView(
        title: String,
        stream: AsyncThrowingStream<String, Error>
    ) -> some View {
        VStack(spacing: 0) {
            ProcessOutputView(title: title, stream: stream)

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    store.dismissAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func severitySectionTitle(_ severity: HealthSeverity) -> String {
        switch severity {
        case .critical: "Critical"
        case .warning: "Warnings"
        case .info: "Info"
        }
    }

    private func runFix(for check: HealthCheck) {
        store.runFix(for: check)
        if case .copyText = check.fixCommand {
            copiedCheckID = check.id
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copiedCheckID == check.id {
                    copiedCheckID = nil
                }
            }
        }
    }
}

// MARK: - HealthCheckRow

private struct HealthCheckRow: View {
    let check: HealthCheck
    let isCopied: Bool
    let onFix: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: severity icon + title + category pill
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: check.severity.icon)
                    .foregroundStyle(check.severity.color)
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    Text(check.title)
                        .fontWeight(.medium)
                        .lineLimit(isExpanded ? nil : 2)

                    categoryPill
                }

                Spacer()

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

            // Solution block (always visible when present)
            if let solution = check.solution {
                solutionBlock(solution)
            }

            // Expanded description
            if isExpanded {
                Text(check.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }

            // Fix button
            if check.fixCommand != nil {
                fixButton
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var categoryPill: some View {
        Label(check.category.title, systemImage: check.category.icon)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    private func solutionBlock(_ solution: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.yellow)
                .frame(width: 3)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)

                Text(solution)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 24)
    }

    @ViewBuilder
    private var fixButton: some View {
        switch check.fixCommand {
        case .brewStream:
            Button {
                onFix()
            } label: {
                Label("Fix", systemImage: "wrench.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .controlSize(.small)

        case .copyText:
            Button {
                onFix()
            } label: {
                Label(
                    isCopied ? "Copied!" : "Copy Command",
                    systemImage: isCopied ? "checkmark" : "doc.on.doc"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(isCopied ? .green : .secondary)
            .controlSize(.small)

        case nil:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthCheckView()
    }
    .frame(width: 600, height: 500)
}
