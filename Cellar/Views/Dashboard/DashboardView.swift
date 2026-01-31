import SwiftUI
import CellarCore

// MARK: - DashboardView

struct DashboardView: View {
    @Binding var selection: SidebarItem?
    @State private var dashboardStore = DashboardStore()
    @Environment(PackageStore.self) private var packageStore

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
                if !summary.services.isEmpty {
                    servicesSection(summary)
                }
                quickActionsSection(summary)
                if !summary.recentlyInstalled.isEmpty {
                    recentlyInstalledSection(summary)
                }
                if !summary.taps.isEmpty {
                    tapsSection(summary)
                }
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
                navigableCard(to: .formulae) {
                    StatCardView(
                        title: "Formulae",
                        value: "\(summary.totalFormulae)",
                        systemImage: "terminal",
                        color: .blue
                    )
                }

                navigableCard(to: .casks) {
                    StatCardView(
                        title: "Casks",
                        value: "\(summary.totalCasks)",
                        systemImage: "macwindow",
                        color: .purple
                    )
                }

                navigableCard(to: .services) {
                    StatCardView(
                        title: "Services",
                        value: "\(summary.runningServices)/\(summary.totalServices)",
                        systemImage: "gearshape.2",
                        color: .green
                    )
                }

                navigableCard(to: .outdated) {
                    StatCardView(
                        title: "Updates",
                        value: "\(summary.updatesAvailable)",
                        systemImage: "arrow.triangle.2.circlepath",
                        color: summary.updatesAvailable > 0 ? .orange : .green
                    )
                }
            }
        }
    }

    // MARK: - Services Section

    private func servicesSection(_ summary: SystemSummary) -> some View {
        let items = Array(summary.services.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Services at a Glance",
                systemImage: "gearshape.2",
                color: .green
            ) {
                seeAllButton(to: .services)
            }

            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, service in
                        Button {
                            selection = .services
                        } label: {
                            serviceRow(service)
                        }
                        .buttonStyle(.plain)

                        if index < items.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func serviceRow(_ service: BrewServiceItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(serviceStatusColor(service.status))
                .frame(width: 8, height: 8)

            Text(service.name)
                .fontWeight(.medium)

            Spacer()

            Text(service.status.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private func serviceStatusColor(_ status: ServiceStatus) -> Color {
        switch status {
        case .started: .green
        case .error: .red
        case .stopped, .none, .unknown: .secondary
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

    // MARK: - Recently Installed Section

    private func recentlyInstalledSection(_ summary: SystemSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Recently Installed",
                systemImage: "clock.arrow.circlepath",
                color: .blue
            ) {
                seeAllButton(to: .formulae)
            }

            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(summary.recentlyInstalled.enumerated()), id: \.element.id) { index, formula in
                        Button {
                            packageStore.selectedFormulaId = formula.id
                            selection = .formulae
                        } label: {
                            recentlyInstalledRow(formula)
                        }
                        .buttonStyle(.plain)

                        if index < summary.recentlyInstalled.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func recentlyInstalledRow(_ formula: Formula) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(formula.name)
                .fontWeight(.medium)

            Spacer()

            if let installTime = formula.installTime {
                Text(Self.relativeDateFormatter.localizedString(for: installTime, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Taps Section

    private func tapsSection(_ summary: SystemSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Taps",
                systemImage: "spigot",
                color: .teal
            ) {
                seeAllButton(to: .taps)
            }

            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(summary.taps.enumerated()), id: \.element.id) { index, tap in
                        Button {
                            selection = .taps
                        } label: {
                            tapRow(tap)
                        }
                        .buttonStyle(.plain)

                        if index < summary.taps.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func tapRow(_ tap: Tap) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "spigot")
                .foregroundStyle(.teal)
                .frame(width: 20)

            Text(tap.name)
                .fontWeight(.medium)

            if tap.official {
                Text("Official")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.gradient, in: Capsule())
            }

            Spacer()

            Text("\(tap.totalPackages) packages")
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Outdated Section

    private func outdatedSection(_ summary: SystemSummary) -> some View {
        let formulae = Array(summary.outdatedFormulae.prefix(5))
        let casks = Array(summary.outdatedCasks.prefix(5))
        let totalShown = formulae.count + casks.count
        let remaining = summary.updatesAvailable - totalShown

        return VStack(alignment: .leading, spacing: 12) {
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
                    ForEach(Array(formulae.enumerated()), id: \.element.id) { index, formula in
                        Button {
                            packageStore.selectedFormulaId = formula.id
                            selection = .formulae
                        } label: {
                            outdatedRow(
                                name: formula.name,
                                description: formula.desc,
                                systemImage: "terminal",
                                iconColor: .blue,
                                currentVersion: formula.version,
                                targetVersion: "latest"
                            )
                        }
                        .buttonStyle(.plain)

                        if index < formulae.count - 1 || !casks.isEmpty || remaining > 0 {
                            Divider()
                        }
                    }

                    ForEach(Array(casks.enumerated()), id: \.element.id) { index, cask in
                        Button {
                            packageStore.selectedCaskId = cask.id
                            selection = .casks
                        } label: {
                            outdatedRow(
                                name: cask.displayName,
                                description: cask.desc,
                                systemImage: "macwindow",
                                iconColor: .purple,
                                currentVersion: cask.installed ?? cask.version,
                                targetVersion: cask.version
                            )
                        }
                        .buttonStyle(.plain)

                        if index < casks.count - 1 || remaining > 0 {
                            Divider()
                        }
                    }

                    if remaining > 0 {
                        Button {
                            selection = .outdated
                        } label: {
                            HStack {
                                Spacer()
                                Text("and \(remaining) more\u{2026}")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func outdatedRow(
        name: String,
        description: String?,
        systemImage: String,
        iconColor: Color,
        currentVersion: String,
        targetVersion: String
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .fontWeight(.medium)

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text(currentVersion)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Text(targetVersion)
                    .font(.callout.monospaced())
                    .foregroundStyle(.orange)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
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

    // MARK: - Helpers

    private func navigableCard<Content: View>(
        to destination: SidebarItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            selection = destination
        } label: {
            content()
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(NavigableCardStyle())
    }

    private func seeAllButton(to destination: SidebarItem) -> some View {
        Button {
            selection = destination
        } label: {
            Text("See All")
                .font(.subheadline)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

// MARK: - Navigable Card Style

private struct NavigableCardStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(isHovered ? 0.03 : 0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
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
        DashboardView(selection: .constant(.dashboard))
            .environment(PackageStore())
    }
    .frame(width: 700, height: 600)
}
