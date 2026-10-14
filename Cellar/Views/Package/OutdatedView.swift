import SwiftUI
import CellarCore

/// The Updates page: outdated packages, how fresh that list is, and
/// upgrading them one by one or all at once.
struct OutdatedView: View {
    @Environment(PackageStore.self) private var store
    @Environment(ActivityStore.self) private var activityStore

    @State private var searchText = ""
    @State private var selection: Set<PackageID> = []
    @State private var uninstallRequest: UninstallRequest?
    @AppStorage(SettingsKey.showsInspector(.package)) private var showsInspector = true

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shownPackages: [PackageType] {
        let packages = store.outdatedPackages
        return query.isEmpty ? packages : packages.filter { $0.matches(query) }
    }

    private var selectedPackage: PackageType? {
        guard selection.count == 1, let id = selection.first else { return nil }
        return store.package(id)
    }

    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                RestartServicesBanner()
            }
            .loadErrorBanner(for: store) { await store.loadAll(forceRefresh: true) }
            .navigationTitle("Updates")
            .dataFreshness(store.lastUpdated)
            .searchable(text: $searchText, prompt: "Search updates")
            .pageRefresh(
                "Check for Updates",
                systemImage: "arrow.triangle.2.circlepath",
                help: "Check for Updates — asks Homebrew for the latest versions (brew update)",
                isLoading: store.isLoading || store.isCheckingForUpdates
            ) {
                await store.checkForUpdates()
            }
            .packageSelection(selectedPackage, uninstallRequest: $uninstallRequest)
            .task {
                await store.loadAll()
            }
    }

    @ViewBuilder
    private var content: some View {
        if (store.isLoading && store.lastUpdated == nil)
            || (store.isCheckingForUpdates && store.totalOutdated == 0) {
            LoadingView(message: "Checking for Updates\u{2026}")
        } else if let errorMessage = store.errorMessage, store.lastUpdated == nil {
            ErrorView(message: errorMessage) {
                Task { await store.loadAll(forceRefresh: true) }
            }
        } else if store.totalOutdated == 0 {
            EmptyStateView(
                title: "Everything Up to Date",
                systemImage: "checkmark.circle",
                description: lastCheckDescription,
                actionTitle: "Check Again"
            ) {
                Task { await store.checkForUpdates() }
            }
        } else {
            outdatedList
        }
    }

    // MARK: - Update Check

    /// "Checked 3 hours ago." — tells whether the list can be trusted.
    private var lastCheckDescription: String {
        guard let lastCheck = store.lastUpdateCheck else {
            return "Check for updates to fetch the latest versions from Homebrew."
        }
        return "Checked \(lastCheck.formatted(.relative(presentation: .named)))."
    }

    // MARK: - List

    private var outdatedList: some View {
        VStack(spacing: 0) {
            if let operation = store.upgradeAllOperation, operation.isRunning {
                RunningOperationBar(operation: operation)
                    .transition(.opacity)
            } else {
                updateSummary
                    .transition(.opacity)
                Divider()
                if let failedBatch {
                    failedBatchBanner(failedBatch)
                }
            }

            List(selection: $selection) {
                ForEach(PackageKind.allCases, id: \.self) { kind in
                    let packages = shownPackages.filter { $0.kind == kind }
                    if !packages.isEmpty {
                        Section {
                            ForEach(packages) { package in
                                OutdatedPackageRow(package: package)
                            }
                        } header: {
                            CountedSectionHeader(title: kind.title, systemImage: kind.systemImage, count: packages.count)
                        }
                    }
                }
            }
            .contextMenu(forSelectionType: PackageID.self) { ids in
                PackageMenu(packages: ids.compactMap(store.package), showDetails: { showDetails(ids) }) {
                    uninstallRequest = $0
                }
            } primaryAction: { ids in
                showDetails(ids)
            }
            .overlay {
                if shownPackages.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .animation(AnimationToken.smooth, value: store.isUpgradingAll)
    }

    /// Double-click or Return: show the clicked package in the inspector.
    private func showDetails(_ ids: Set<PackageID>) {
        guard let id = ids.first else { return }
        selection = [id]
        showsInspector = true
    }

    // MARK: - Summary

    private var updateSummary: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: IconSize.mediumIcon, height: IconSize.mediumIcon)
                .background(.orange.opacity(Opacity.iconBackground), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(summaryTitle)
                    .font(.headline)
                if store.isCheckingForUpdates {
                    Label {
                        Text("Checking for updates\u{2026}")
                    } icon: {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(lastCheckDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.isUpgradePreviewPresented = true
            } label: {
                Label("Upgrade All\u{2026}", systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .help("Choose which packages to upgrade, with download sizes")
            .disabled(!store.canUpgradeAll)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.row)
        .background(.orange.opacity(Opacity.bannerBackground))
    }

    /// "5 updates · 2 pinned".
    private var summaryTitle: String {
        let total = store.totalOutdated
        let updates = String.count(total, "update")
        let pinned = store.pinnedOutdatedCount
        return pinned > 0 ? "\(updates) · \(pinned) pinned" : updates
    }

    // MARK: - Failed Batch

    /// The latest Upgrade All, if it failed and can be retried.
    private var failedBatch: BrewOperation? {
        guard let operation = store.upgradeAllOperation, activityStore.canRetry(operation.id) else { return nil }
        return operation
    }

    private func failedBatchBanner(_ operation: BrewOperation) -> some View {
        NoticeBanner(
            tint: .red,
            systemImage: "exclamationmark.triangle.fill",
            title: "\(operation.failedSteps.map(\.name).formatted(.list(type: .and))) failed to upgrade."
        ) {
            Button("Details") {
                ActivityPanel.show()
            }
            Button("Retry") {
                Task { await activityStore.retry(operation.id) }
            }
        }
    }
}

// MARK: - Outdated Package Row

private struct OutdatedPackageRow: View {
    let package: PackageType

    @Environment(PackageStore.self) private var store
    @Environment(ActivityStore.self) private var activityStore

    var body: some View {
        HStack(spacing: Spacing.sectionContent) {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                HStack(spacing: Spacing.compact) {
                    Text(package.name)
                        .fontWeight(.medium)
                    if package.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("Pinned — upgrades skip this formula")
                            .accessibilityLabel("Pinned")
                    }
                }
                if let description = package.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            versions

            if let activity = PackageActivity(package, activityStore: activityStore) {
                PackageActivityLabel(activity: activity)
                    .frame(minWidth: 96, alignment: .leading)
            } else {
                upgradeButton
            }
        }
        .padding(.vertical, Spacing.compact)
    }

    private var versions: some View {
        HStack(spacing: Spacing.compact) {
            Text(package.version)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityLabel("to")
            Text(package.latestVersion)
                .foregroundStyle(.orange)
        }
        .font(.callout.monospaced())
        .accessibilityElement(children: .combine)
    }

    /// Icon-only so the row doesn't shift; a pinned formula offers
    /// Unpin and Upgrade, since brew won't upgrade it while pinned.
    @ViewBuilder
    private var upgradeButton: some View {
        if let primary = PackagePrimaryAction(package: package, store: store) {
            Button {
                Task { await primary.perform() }
            } label: {
                Label(primary.help, systemImage: primary.systemImage)
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .controlSize(.small)
            .help(primary.help)
            .accessibilityLabel(primary.help)
            .disabled(store.isUpgradingAll)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        OutdatedView()
            .environment(AppStores())
    }
    .frame(width: 600, height: 500)
}
