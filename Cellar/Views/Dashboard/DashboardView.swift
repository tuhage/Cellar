import SwiftUI
import CellarCore

// MARK: - DashboardView

struct DashboardView: View {
    @State private var dashboardStore = DashboardStore()

    var body: some View {
        Group {
            if let stream = dashboardStore.actionStream {
                actionOutputView(
                    title: dashboardStore.actionTitle ?? "Running",
                    stream: stream
                )
            } else if let summary = dashboardStore.summary {
                dashboardContent(summary)
            } else if let errorMessage = dashboardStore.errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await dashboardStore.load() }
                }
            } else {
                LoadingView(message: "Loading dashboard\u{2026}")
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
    }

    // MARK: - Stats Section

    private func statsSection(_ summary: SystemSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Overview", systemImage: "chart.bar.fill", color: .secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 12
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
    }

    // MARK: - Quick Actions Section

    private func quickActionsSection(_ summary: SystemSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Quick Actions", systemImage: "bolt.fill", color: .secondary)

            HStack(spacing: 12) {
                quickActionButton(
                    title: "Upgrade All",
                    subtitle: summary.updatesAvailable > 0
                        ? "\(summary.updatesAvailable) available"
                        : "All up to date",
                    systemImage: "arrow.up.circle.fill",
                    color: .orange,
                    disabled: summary.updatesAvailable == 0
                ) {
                    dashboardStore.upgradeAll()
                }

                quickActionButton(
                    title: "Cleanup",
                    subtitle: "Free disk space",
                    systemImage: "trash.circle.fill",
                    color: .red
                ) {
                    dashboardStore.cleanup()
                }

                quickActionButton(
                    title: "Health Check",
                    subtitle: "Run brew doctor",
                    systemImage: "heart.circle.fill",
                    color: .pink
                ) {
                    dashboardStore.healthCheck()
                }
            }
        }
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isDisabled = disabled || dashboardStore.isPerformingAction

        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(QuickActionStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
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
                    dashboardStore.dismissAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}

// MARK: - Quick Action Button Style

private struct QuickActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? .tertiary : .quaternary)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
    .frame(width: 700, height: 600)
}
