import SwiftUI
import CellarCore

/// Confirms Upgrade All with what brew will actually do: every package,
/// those pulled in as dependencies, the download size, and running services
/// that will need a restart.
struct UpgradeAllSheet: View {
    @Environment(PackageStore.self) private var store
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(\.dismiss) private var dismiss

    @State private var plan: UpgradePlan?
    @State private var planError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(Spacing.cardPadding)
            Divider()
            packageList
            Divider()
            footer
                .padding(Spacing.cardPadding)
        }
        .frame(width: 520, height: 500)
        .task { await loadPlan() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text("Upgrade \(packageCount) \(packageCount == 1 ? "Package" : "Packages")")
                    .font(.headline)
                Text("Packages upgrade one at a time; you can follow and cancel each step.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - List

    private var packageList: some View {
        List {
            Section("Packages") {
                ForEach(store.upgradableFormulae) { formula in
                    PlanRow(
                        name: formula.name,
                        currentVersion: formula.version,
                        targetVersion: formula.latestVersion ?? "latest",
                        size: plannedItem(named: formula.fullName)?.downloadBytes,
                        isPlanLoading: plan == nil && planError == nil
                    )
                }
                ForEach(store.outdatedCasks) { cask in
                    PlanRow(
                        name: cask.displayName,
                        currentVersion: cask.installed ?? cask.version,
                        targetVersion: cask.version,
                        size: plannedItem(named: cask.fullToken.isEmpty ? cask.token : cask.fullToken)?.downloadBytes,
                        isPlanLoading: plan == nil && planError == nil
                    )
                }
            }

            if let additional = plan?.additionalItems, !additional.isEmpty {
                Section {
                    ForEach(additional) { item in
                        PlanRow(
                            name: item.shortName,
                            currentVersion: item.currentVersion,
                            targetVersion: item.targetVersion,
                            size: item.downloadBytes,
                            isPlanLoading: false
                        )
                    }
                } header: {
                    Text("Also Upgraded")
                } footer: {
                    Text("Needed by the packages above.")
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            VStack(alignment: .leading, spacing: Spacing.compact) {
                downloadSummary
                if store.pinnedOutdatedCount > 0 {
                    let pinned = store.pinnedOutdatedCount
                    Label(
                        "\(pinned) pinned \(pinned == 1 ? "formula is" : "formulae are") skipped.",
                        systemImage: "pin"
                    )
                }
                if !affectedServices.isEmpty {
                    Label(
                        "\(affectedServices.formatted(.list(type: .and))) will keep running the old version until restarted; Cellar offers a restart afterwards.",
                        systemImage: "arrow.clockwise"
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Upgrade") {
                    store.upgradeAll()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(packageCount == 0 || store.isCheckingForUpdates || store.isUpgradingAll)
            }
        }
    }

    @ViewBuilder
    private var downloadSummary: some View {
        if let plan {
            if plan.totalDownloadBytes > 0 {
                Label(
                    "Up to \(plan.totalDownloadBytes.formatted(.byteCount(style: .file))) to download.",
                    systemImage: "arrow.down.circle"
                )
            }
        } else if let planError {
            Label("Couldn't preview the download: \(planError)", systemImage: "exclamationmark.triangle")
                .lineLimit(2)
        } else {
            Label {
                Text("Checking download size\u{2026}")
            } icon: {
                ProgressView()
                    .controlSize(.mini)
            }
        }
    }

    // MARK: - Data

    private var packageCount: Int {
        store.upgradableFormulae.count + store.outdatedCasks.count
    }

    /// Running services whose formula is about to be upgraded.
    private var affectedServices: [String] {
        let names = Set(store.upgradableFormulae.map(\.name))
            .union(plan?.items.filter { !$0.isCask }.map(\.shortName) ?? [])
        return serviceStore.services
            .filter { $0.isRunning && names.contains($0.name) }
            .map(\.name)
    }

    private func plannedItem(named name: String) -> UpgradePlan.Item? {
        plan?.items.first { $0.name == name }
    }

    private func loadPlan() async {
        do {
            plan = try await UpgradePlan.dryRun(
                formulae: store.upgradableFormulae.map(\.fullName),
                casks: store.outdatedCasks.map { $0.fullToken.isEmpty ? $0.token : $0.fullToken }
            )
        } catch {
            guard !isOperationCancellation(error) else { return }
            planError = (error as? BrewError).flatMap(Self.briefMessage) ?? error.localizedDescription
        }
    }

    private static func briefMessage(_ error: BrewError) -> String? {
        guard case .processFailure(_, let stderr) = error else { return nil }
        return stderr.split(whereSeparator: \.isNewline).last.map(String.init)
    }
}

// MARK: - Row

private struct PlanRow: View {
    let name: String
    let currentVersion: String
    let targetVersion: String
    let size: Int64?
    let isPlanLoading: Bool

    var body: some View {
        HStack(spacing: Spacing.item) {
            Text(name)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer(minLength: Spacing.item)
            Text("\(currentVersion) → \(targetVersion)")
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Group {
                if let size {
                    Text(size.formatted(.byteCount(style: .file)))
                } else if isPlanLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("—")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    UpgradeAllSheet()
        .environment(PackageStore())
        .environment(ServiceStore())
}
