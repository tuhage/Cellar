import SwiftUI
import CellarCore

// MARK: - DashboardView

/// The overview: what needs attention first, then counts, services,
/// updates, recent installs and taps. Every row opens its item.
struct DashboardView: View {
    @Binding var selection: SidebarItem?

    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(TapStore.self) private var tapStore
    @Environment(MaintenanceStore.self) private var maintenanceStore
    @Environment(ActivityStore.self) private var activityStore
    @Environment(\.refreshAll) private var refreshAll

    private static let listLimit = 5

    var body: some View {
        Group {
            if let summary {
                content(summary)
            } else if let errorMessage = packageStore.errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await refreshAll() }
                }
            } else {
                LoadingView(message: "Loading Dashboard\u{2026}")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            attentionBanners
        }
        .navigationTitle("Dashboard")
        .dataFreshness(packageStore.lastUpdated)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: packageStore.isLoading || serviceStore.isLoading) {
                    await refreshAll()
                }
            }
        }
        .focusedSceneValue(\.pageRefresh, refreshAll)
    }

    /// `nil` until the first data arrives.
    private var summary: SystemSummary? {
        guard packageStore.lastUpdated != nil || serviceStore.lastUpdated != nil else { return nil }
        return SystemSummary.current(
            formulae: packageStore.formulae,
            casks: packageStore.casks,
            services: serviceStore.services,
            taps: tapStore.taps
        )
    }

    // MARK: - Needs Attention

    @ViewBuilder
    private var attentionBanners: some View {
        if let message = packageStore.errorMessage ?? serviceStore.errorMessage, summary != nil {
            LoadErrorBanner(message: message, lastUpdated: packageStore.lastUpdated) {
                await refreshAll()
            }
        }

        let failedServices = serviceStore.services.filter(\.isError)
        if let firstFailed = failedServices.first {
            NoticeBanner(
                tint: .red,
                systemImage: "exclamationmark.octagon.fill",
                title: failedServices.count == 1
                    ? "\(firstFailed.name) failed"
                    : "\(failedServices.count) services failed",
                message: "Open Services to see the exit code and logs."
            ) {
                Button("Show") { open(firstFailed) }
            }
        }

        let staleServices = serviceStore.servicesNeedingRestart(formulae: packageStore.formulae)
        if !staleServices.isEmpty {
            RestartServicesBanner(
                services: staleServices,
                isRestarting: staleServices.contains { activityStore.isActive(.package($0.name)) }
            ) {
                Task { await serviceStore.restart(staleServices) }
            }
        }

        if activityStore.failedCount > 0 {
            NoticeBanner(
                tint: .orange,
                systemImage: "exclamationmark.triangle.fill",
                title: activityStore.failedCount == 1
                    ? "An operation failed"
                    : "\(activityStore.failedCount) operations failed"
            ) {
                Button("Show Activity") {
                    NotificationCenter.default.post(name: .openActivityPanel, object: nil)
                }
            }
        }
    }

    // MARK: - Content

    private func content(_ summary: SystemSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                stats(summary)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.section) {
                        VStack(alignment: .leading, spacing: Spacing.section) {
                            primaryColumn(summary)
                        }
                        .frame(minWidth: 420, maxWidth: .infinity, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: Spacing.section) {
                            secondaryColumn(summary)
                        }
                        .frame(minWidth: 360, idealWidth: 420, maxWidth: 480, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: Spacing.section) {
                        secondaryColumn(summary)
                        primaryColumn(summary)
                    }
                }
            }
            .padding(Spacing.section)
        }
    }

    @ViewBuilder
    private func primaryColumn(_ summary: SystemSummary) -> some View {
        if !summary.services.isEmpty {
            servicesCard(summary)
        }
        if !summary.recentlyInstalled.isEmpty {
            recentlyInstalledCard(summary)
        }
        if !summary.taps.isEmpty {
            tapsCard(summary)
        }
    }

    @ViewBuilder
    private func secondaryColumn(_ summary: SystemSummary) -> some View {
        quickActions(summary)
        if summary.hasOutdatedPackages {
            updatesCard(summary)
        }
    }

    // MARK: - Stats

    private func stats(_ summary: SystemSummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 210), spacing: Spacing.sectionContent)],
            spacing: Spacing.sectionContent
        ) {
            statCard(.formulae, value: "\(summary.totalFormulae)", color: .blue)
            statCard(.casks, value: "\(summary.totalCasks)", color: .purple)
            statCard(
                .services,
                value: "\(summary.runningServices)/\(summary.totalServices)",
                color: summary.hasFailedServices ? .red : .green,
                accessibilityValue: "\(summary.runningServices) of \(summary.totalServices) running"
            )
            statCard(.outdated, value: "\(summary.updatesAvailable)", color: summary.hasOutdatedPackages ? .orange : .green)
        }
    }

    private func statCard(
        _ item: SidebarItem,
        value: String,
        color: Color,
        accessibilityValue: String? = nil
    ) -> some View {
        Button {
            selection = item
        } label: {
            StatCardView(
                title: item.title,
                value: value,
                systemImage: item.icon,
                color: color,
                accessibilityValue: accessibilityValue
            )
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityHint("Opens \(item.title)")
    }

    // MARK: - Quick Actions

    private func quickActions(_ summary: SystemSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            SectionHeaderView(title: "Quick Actions", systemImage: "bolt.fill", color: .secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sectionContent) { quickActionButtons(summary) }
                VStack(spacing: Spacing.sectionContent) { quickActionButtons(summary) }
            }
        }
    }

    @ViewBuilder
    private func quickActionButtons(_ summary: SystemSummary) -> some View {
        QuickActionButton(
            title: packageStore.isUpgradingAll ? "Upgrading\u{2026}" : "Upgrade All",
            subtitle: upgradeAllSubtitle(summary),
            systemImage: "arrow.up.circle.fill",
            color: .orange,
            isDisabled: !packageStore.isUpgradingAll
                && (!summary.hasOutdatedPackages || packageStore.isCheckingForUpdates),
            isProminent: true
        ) {
            if packageStore.isUpgradingAll {
                NotificationCenter.default.post(name: .openActivityPanel, object: nil)
            } else {
                packageStore.isUpgradePreviewPresented = true
            }
        }

        QuickActionButton(
            title: "Clean Up",
            subtitle: maintenanceStore.runningTask?.kind == .cleanup ? "Cleaning up\u{2026}" : "Free disk space",
            systemImage: "trash.circle.fill",
            color: .blue,
            isDisabled: maintenanceStore.isRunning
        ) {
            maintenanceStore.isCleanupPreviewPresented = true
        }

        QuickActionButton(
            title: "Health Check",
            subtitle: maintenanceStore.runningTask?.kind == .healthCheck ? "Checking\u{2026}" : "Run brew doctor",
            systemImage: "heart.circle.fill",
            color: .green,
            isDisabled: maintenanceStore.isRunning
        ) {
            Task { await maintenanceStore.runHealthCheck() }
        }
    }

    private func upgradeAllSubtitle(_ summary: SystemSummary) -> String {
        if let operation = packageStore.upgradeAllOperation, operation.isRunning {
            guard let step = operation.currentStep, let position = operation.currentStepNumber else {
                return "Show progress"
            }
            return "\(step.name) · \(position) of \(operation.steps.count)"
        }
        if packageStore.isCheckingForUpdates {
            return "Checking for updates\u{2026}"
        }
        return summary.hasOutdatedPackages ? "\(summary.updatesAvailable) available" : "All up to date"
    }

    // MARK: - Lists

    private func servicesCard(_ summary: SystemSummary) -> some View {
        DashboardListCard(
            title: "Services",
            systemImage: SidebarItem.services.icon,
            color: .green,
            items: Array(summary.services.prefix(Self.listLimit)),
            hiddenCount: summary.services.count - Self.listLimit,
            seeAll: { selection = .services },
            select: open
        ) { service in
            HStack(spacing: Spacing.row) {
                Image(systemName: "circle.fill")
                    .font(.system(size: IconSize.statusDot))
                    .foregroundStyle(service.status.color)
                    .accessibilityHidden(true)
                Text(service.name)
                    .fontWeight(.medium)
                Spacer()
                Text(service.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func updatesCard(_ summary: SystemSummary) -> some View {
        let updates = summary.outdatedFormulae.map(DashboardUpdate.init(formula:))
            + summary.outdatedCasks.map(DashboardUpdate.init(cask:))
        return DashboardListCard(
            title: "Updates",
            systemImage: SidebarItem.outdated.icon,
            color: .orange,
            items: Array(updates.prefix(Self.listLimit)),
            hiddenCount: updates.count - Self.listLimit,
            seeAll: { selection = .outdated },
            select: open
        ) { update in
            HStack(spacing: Spacing.row) {
                Image(systemName: update.isCask ? SidebarItem.casks.icon : SidebarItem.formulae.icon)
                    .foregroundStyle(update.isCask ? .purple : .blue)
                    .frame(width: IconSize.iconColumn)
                    .accessibilityLabel(update.isCask ? "Cask" : "Formula")
                Text(update.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text("\(update.currentVersion) → \(update.targetVersion)")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func recentlyInstalledCard(_ summary: SystemSummary) -> some View {
        DashboardListCard(
            title: "Recently Installed",
            systemImage: "clock.arrow.circlepath",
            color: .blue,
            items: summary.recentlyInstalled,
            seeAll: { selection = .formulae },
            select: { formula in open(DashboardUpdate(formula: formula)) }
        ) { formula in
            HStack(spacing: Spacing.row) {
                Image(systemName: SidebarItem.formulae.icon)
                    .foregroundStyle(.blue)
                    .frame(width: IconSize.iconColumn)
                    .accessibilityHidden(true)
                Text(formula.name)
                    .fontWeight(.medium)
                Spacer()
                if let installTime = formula.installTime {
                    Text(installTime, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func tapsCard(_ summary: SystemSummary) -> some View {
        DashboardListCard(
            title: "Taps",
            systemImage: SidebarItem.taps.icon,
            color: .teal,
            items: Array(summary.taps.prefix(Self.listLimit)),
            hiddenCount: summary.taps.count - Self.listLimit,
            seeAll: { selection = .taps },
            select: { _ in selection = .taps }
        ) { tap in
            HStack(spacing: Spacing.row) {
                Text(tap.name)
                    .fontWeight(.medium)
                if tap.official {
                    StatusBadge(text: "Official", color: .blue)
                }
                Spacer()
                Text("\(tap.totalPackages) packages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Navigation

    private func open(_ service: BrewServiceItem) {
        serviceStore.selectedServiceId = service.id
        selection = .services
    }

    private func open(_ update: DashboardUpdate) {
        if update.isCask {
            packageStore.selectedCaskId = update.id
            selection = .casks
        } else {
            packageStore.selectedFormulaId = update.id
            selection = .formulae
        }
    }
}

// MARK: - Dashboard List Card

/// A titled card listing a few items; each row opens its item and "See All"
/// opens the full page.
private struct DashboardListCard<Item: Identifiable, Row: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    let items: [Item]
    var hiddenCount = 0
    let seeAll: () -> Void
    let select: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            SectionHeaderView(title: title, systemImage: systemImage, color: color) {
                Button(hiddenCount > 0 ? "See All (\(items.count + hiddenCount))" : "See All", action: seeAll)
                    .buttonStyle(.link)
            }

            VStack(spacing: 0) {
                DividedForEach(data: items) { item in
                    Button {
                        select(item)
                    } label: {
                        row(item)
                            .listRowInset()
                            .padding(.horizontal, Spacing.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(CardButtonStyle(cornerRadius: CornerRadius.small))
                }
            }
            .padding(Spacing.compact)
            .cardStyle()
        }
    }
}

// MARK: - Dashboard Update

/// An outdated formula or cask as one dashboard row.
private struct DashboardUpdate: Identifiable {
    let id: String
    let name: String
    let isCask: Bool
    let currentVersion: String
    let targetVersion: String

    init(formula: Formula) {
        id = formula.id
        name = formula.name
        isCask = false
        currentVersion = formula.version
        targetVersion = formula.latestVersion ?? "latest"
    }

    init(cask: Cask) {
        id = cask.id
        name = cask.displayName
        isCask = true
        currentVersion = cask.installed ?? cask.version
        targetVersion = cask.version
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selection: SidebarItem? = .dashboard
    NavigationStack {
        DashboardView(selection: $selection)
    }
    .environment(AppStores())
    .frame(width: 1000, height: 760)
}
