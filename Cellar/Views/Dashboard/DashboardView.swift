import SwiftUI
import CellarCore

// MARK: - DashboardView

struct DashboardView: View {
    @State private var dashboardStore = DashboardStore()

    var body: some View {
        Group {
            if dashboardStore.isLoading && dashboardStore.summary == nil {
                LoadingView(message: "Loading dashboard\u{2026}")
            } else if let errorMessage = dashboardStore.errorMessage,
                      dashboardStore.summary == nil {
                ErrorView(message: errorMessage) {
                    Task { await dashboardStore.load() }
                }
            } else if let summary = dashboardStore.summary {
                dashboardContent(summary)
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await dashboardStore.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(dashboardStore.isLoading)
            }
        }
        .task {
            await dashboardStore.load()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func dashboardContent(_ summary: SystemSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statsSection(summary)
                quickActionsSection(summary)
                if summary.updatesAvailable > 0 {
                    outdatedSection(summary)
                }
            }
            .padding(24)
        }
        .sheet(item: actionOutputBinding) { output in
            ActionOutputSheet(
                output: output.text,
                onDismiss: { dashboardStore.dismissActionOutput() }
            )
        }
        .overlay {
            if dashboardStore.isPerformingAction {
                actionOverlay
            }
        }
    }

    // MARK: - Stats Section

    private func statsSection(_ summary: SystemSummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)],
            spacing: 16
        ) {
            StatCardView(
                title: "Formulae",
                value: "\(summary.totalFormulae)",
                systemImage: "terminal",
                color: .blue
            )

            StatCardView(
                title: "Casks",
                value: "\(summary.totalCasks)",
                systemImage: "macwindow",
                color: .purple
            )

            StatCardView(
                title: "Services",
                value: "\(summary.runningServices)/\(summary.totalServices)",
                systemImage: "gearshape.2",
                color: .green
            )

            StatCardView(
                title: "Updates",
                value: "\(summary.updatesAvailable)",
                systemImage: "arrow.triangle.2.circlepath",
                color: summary.updatesAvailable > 0 ? .orange : .green
            )
        }
    }

    // MARK: - Quick Actions Section

    private func quickActionsSection(_ summary: SystemSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Quick Actions", systemImage: "bolt.fill", color: .blue)

            HStack(spacing: 12) {
                quickActionButton(
                    title: "Upgrade All",
                    systemImage: "arrow.up.circle.fill",
                    color: .orange,
                    disabled: summary.updatesAvailable == 0
                ) {
                    await dashboardStore.upgradeAll()
                }

                quickActionButton(
                    title: "Cleanup",
                    systemImage: "trash.circle.fill",
                    color: .red
                ) {
                    await dashboardStore.cleanup()
                }

                quickActionButton(
                    title: "Health Check",
                    systemImage: "heart.circle.fill",
                    color: .pink
                ) {
                    await dashboardStore.healthCheck()
                }
            }
        }
    }

    private func quickActionButton(
        title: String,
        systemImage: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
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
        .disabled(disabled || dashboardStore.isPerformingAction)
    }

    // MARK: - Outdated Section

    private func outdatedSection(_ summary: SystemSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Outdated Packages",
                systemImage: "arrow.triangle.2.circlepath",
                color: .orange
            ) {
                Text("\(summary.updatesAvailable) update\(summary.updatesAvailable == 1 ? "" : "s") available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(summary.outdatedFormulae.prefix(5))) { formula in
                        outdatedFormulaRow(formula)
                        if formula.id != summary.outdatedFormulae.prefix(5).last?.id
                            || !summary.outdatedCasks.isEmpty {
                            Divider()
                        }
                    }

                    ForEach(Array(summary.outdatedCasks.prefix(5))) { cask in
                        outdatedCaskRow(cask)
                        if cask.id != summary.outdatedCasks.prefix(5).last?.id {
                            Divider()
                        }
                    }

                    let totalShown = min(summary.outdatedFormulae.count, 5)
                        + min(summary.outdatedCasks.count, 5)
                    if summary.updatesAvailable > totalShown {
                        Divider()
                        HStack {
                            Spacer()
                            Text("and \(summary.updatesAvailable - totalShown) more\u{2026}")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private func outdatedFormulaRow(_ formula: Formula) -> some View {
        HStack {
            Image(systemName: "terminal")
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(formula.name)
                    .fontWeight(.medium)

                if let desc = formula.desc {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text(formula.version)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Text("latest")
                    .font(.callout.monospaced())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private func outdatedCaskRow(_ cask: Cask) -> some View {
        HStack {
            Image(systemName: "macwindow")
                .foregroundStyle(.purple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(cask.displayName)
                    .fontWeight(.medium)

                if let desc = cask.desc {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text(cask.installed ?? cask.version)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Text(cask.version)
                    .font(.callout.monospaced())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: - Action Overlay

    private var actionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)

                if let label = dashboardStore.activeActionLabel {
                    Text("\(label)\u{2026}")
                        .font(.headline)
                }
            }
            .padding(32)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Action Output Binding

    private var actionOutputBinding: Binding<ActionOutputItem?> {
        Binding(
            get: {
                dashboardStore.actionOutput.map { ActionOutputItem(text: $0) }
            },
            set: { newValue in
                if newValue == nil {
                    dashboardStore.dismissActionOutput()
                }
            }
        )
    }
}

// MARK: - ActionOutputItem

/// Wrapper to make action output `Identifiable` for sheet presentation.
private struct ActionOutputItem: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - ActionOutputSheet

private struct ActionOutputSheet: View {
    let output: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Action Output")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 300)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
    .frame(width: 700, height: 600)
}
