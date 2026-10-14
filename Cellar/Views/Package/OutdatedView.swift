import SwiftUI
import CellarCore

struct OutdatedView: View {
    @Environment(PackageStore.self) private var store
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(ActivityStore.self) private var activityStore

    @State private var isConfirmingUpgradeAll = false
    @State private var searchText = ""

    private var filteredFormulae: [Formula] {
        guard !searchText.isEmpty else { return store.outdatedFormulae }
        return store.outdatedFormulae.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredCasks: [Cask] {
        guard !searchText.isEmpty else { return store.outdatedCasks }
        return store.outdatedCasks.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if (store.isLoading && store.formulae.isEmpty && store.casks.isEmpty)
                || (store.isCheckingForUpdates && store.totalOutdated == 0) {
                LoadingView(message: "Checking for Updates\u{2026}")
            } else if let errorMessage = store.errorMessage,
                      store.formulae.isEmpty && store.casks.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await store.loadAll() }
                }
            } else if store.outdatedFormulae.isEmpty && store.outdatedCasks.isEmpty {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            restartBanner
        }
        .navigationTitle("Outdated")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search outdated packages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.isLoading || store.isCheckingForUpdates) {
                    await store.checkForUpdates()
                }
            }
        }
        .task {
            await store.loadAll()
        }
        .sheet(isPresented: $isConfirmingUpgradeAll) {
            UpgradeAllSheet()
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

    // MARK: - Restart Banner

    private var servicesNeedingRestart: [BrewServiceItem] {
        serviceStore.servicesNeedingRestart(formulae: store.formulae)
    }

    @ViewBuilder
    private var restartBanner: some View {
        let services = servicesNeedingRestart
        if !services.isEmpty {
            VStack(spacing: 0) {
                RestartServicesBanner(
                    services: services,
                    isRestarting: services.contains { activityStore.isActive(target: $0.name) }
                ) {
                    Task { await serviceStore.restart(services) }
                }
                Divider()
            }
        }
    }

    // MARK: - List

    private var outdatedList: some View {
        VStack(spacing: 0) {
            if store.isUpgradingAll {
                upgradeAllProgress
                    .transition(.opacity)
            } else {
                updateSummary
                    .transition(.opacity)
                if let failedBatch {
                    Divider()
                    failedBatchSummary(failedBatch)
                }
            }
            Divider()

            List {
                if !filteredFormulae.isEmpty {
                    Section {
                        ForEach(filteredFormulae) { formula in
                            OutdatedPackageRow(
                                name: formula.name,
                                packageName: formula.name,
                                isCask: false,
                                isPinned: formula.pinned,
                                description: formula.desc,
                                currentVersion: formula.version,
                                targetVersion: formula.latestVersion ?? "latest",
                                isBatchRunning: store.isUpgradingAll
                            ) {
                                Task { await store.upgrade(formula) }
                            }
                        }
                    } header: {
                        CountedSectionHeader(title: "Formulae", systemImage: "terminal", count: filteredFormulae.count)
                    }
                }

                if !filteredCasks.isEmpty {
                    Section {
                        ForEach(filteredCasks) { cask in
                            OutdatedPackageRow(
                                name: cask.displayName,
                                packageName: cask.token,
                                isCask: true,
                                isPinned: false,
                                description: cask.desc,
                                currentVersion: cask.installed ?? cask.version,
                                targetVersion: cask.version,
                                isBatchRunning: store.isUpgradingAll
                            ) {
                                Task { await store.upgrade(cask) }
                            }
                        }
                    } header: {
                        CountedSectionHeader(title: "Casks", systemImage: "macwindow", count: filteredCasks.count)
                    }
                }
            }
        }
        .animation(AnimationToken.smooth, value: store.isUpgradingAll)
    }

    private var updateSummary: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: IconSize.mediumIcon, height: IconSize.mediumIcon)
                .background(.orange.opacity(Opacity.iconBackground), in: RoundedRectangle(cornerRadius: CornerRadius.medium))

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text("\(store.totalOutdated) updates available")
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
                isConfirmingUpgradeAll = true
            } label: {
                Label("Upgrade All", systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(store.isUpgradingAll || store.isCheckingForUpdates)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.row)
        .background(.orange.opacity(0.045))
    }

    // MARK: - Failed Batch

    /// The latest Upgrade All, if it left packages that can be retried.
    private var failedBatch: BrewOperation? {
        guard let operation = store.upgradeAllOperation,
              store.canRetryFailedUpgrades(of: operation)
        else { return nil }
        return operation
    }

    private func failedBatchSummary(_ operation: BrewOperation) -> some View {
        let names = operation.failedSteps.map(\.name).formatted(.list(type: .and))
        return HStack(spacing: Spacing.item) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text("\(names) failed to upgrade.")
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Spacing.item)
            Button("Details") {
                NotificationCenter.default.post(name: .openActivityPanel, object: nil)
            }
            Button("Retry") {
                store.retryFailedUpgrades(of: operation)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.item)
        .background(.red.opacity(0.05))
    }

    // MARK: - Upgrade All Progress

    /// Takes the summary bar's place while Upgrade All runs, so progress is
    /// visible without covering the list.
    private var upgradeAllProgress: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: IconSize.mediumIcon, height: IconSize.mediumIcon)
                .background(.orange.opacity(Opacity.iconBackground), in: RoundedRectangle(cornerRadius: CornerRadius.medium))

            Group {
                if let operation = store.upgradeAllOperation {
                    BatchProgressView(operation: operation)
                } else {
                    Text("Upgrading all packages\u{2026}")
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: Spacing.item) {
                Button("Details") {
                    NotificationCenter.default.post(name: .openActivityPanel, object: nil)
                }
                .help("Show every package and brew's output in Activity")

                Button("Cancel") {
                    store.cancelUpgradeAll()
                }
                .disabled(store.upgradeAllOperation?.isRunning == false)
                .help("Stop after cancelling the package that is upgrading now")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.row)
        .background(.orange.opacity(0.045))
    }

}

// MARK: - Outdated Package Row

private struct OutdatedPackageRow: View {
    let name: String
    /// Formula name or cask token, as used by brew and activity tracking.
    let packageName: String
    let isCask: Bool
    let isPinned: Bool
    let description: String?
    let currentVersion: String
    let targetVersion: String
    let isBatchRunning: Bool
    let upgradeAction: () -> Void

    @Environment(ActivityStore.self) private var activityStore
    @State private var isHovered = false

    private var isUpgrading: Bool {
        activityStore.isActive(target: packageName)
    }

    private var batchStep: BrewOperation.Step? {
        activityStore.runningBatchStep(name: packageName, isCask: isCask)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                HStack(spacing: Spacing.compact) {
                    Text(name)
                        .fontWeight(.medium)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("Pinned — Upgrade All skips this formula")
                            .accessibilityLabel("Pinned")
                    }
                }

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: Spacing.compact) {
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

            if let batchStep {
                batchStatus(batchStep.status)
            } else {
                upgradeButton
            }
        }
        .padding(.vertical, Spacing.compact)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var upgradeButton: some View {
        Button {
            upgradeAction()
        } label: {
            if isUpgrading {
                ProgressView()
                    .controlSize(.small)
            } else if isHovered {
                Label("Upgrade", systemImage: "arrow.up.circle")
            } else {
                Image(systemName: "arrow.up.circle")
            }
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .controlSize(.small)
        .disabled(isUpgrading || isBatchRunning)
    }

    /// Where this package stands inside a running Upgrade All.
    private func batchStatus(_ status: BrewOperation.StepStatus) -> some View {
        HStack(spacing: Spacing.compact) {
            StepStatusIcon(status: status)
            Text(status.label)
                .font(.caption)
                .foregroundStyle(status == .pending ? AnyShapeStyle(.secondary) : AnyShapeStyle(status.color))
        }
        .frame(minWidth: 96, alignment: .leading)
        .help(statusHelp(status))
    }

    private func statusHelp(_ status: BrewOperation.StepStatus) -> String {
        if case .failed(let reason) = status { return reason }
        return status.label
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        OutdatedView()
            .environment(PackageStore())
            .environment(ServiceStore())
            .environment(ActivityStore())
    }
    .frame(width: 600, height: 500)
}
