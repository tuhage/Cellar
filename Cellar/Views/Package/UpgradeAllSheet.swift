import SwiftUI
import CellarCore

/// Confirms Upgrade All with what brew will actually do: every package —
/// each can be left out — those pulled in as dependencies, the download
/// size, pinned formulae that are skipped, and running services that will
/// need a restart.
struct UpgradeAllSheet: View {
    @Environment(PackageStore.self) private var store
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(\.dismiss) private var dismiss

    @State private var plan: UpgradePlan?
    @State private var planError: String?
    /// Packages the user unchecked.
    @State private var excluded: Set<PackageID> = []

    /// Every package Upgrade All can touch; pinned formulae can't be.
    private var candidates: [PackageType] {
        store.outdatedPackages.filter(\.canUpgrade)
    }

    private var selected: [PackageType] {
        candidates.filter { !excluded.contains($0.id) }
    }

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
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text("Upgrade \(String.count(selected.count, "Package"))")
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
            Section {
                ForEach(candidates) { package in
                    Toggle(isOn: inclusion(of: package)) {
                        PlanRow(
                            kind: package.kind,
                            name: package.name,
                            currentVersion: package.version,
                            targetVersion: package.latestVersion,
                            size: plannedItem(for: package)?.downloadBytes,
                            isPlanLoading: plan == nil && planError == nil
                        )
                    }
                    .toggleStyle(.checkbox)
                }
            } header: {
                HStack {
                    Text("Packages")
                    Spacer()
                    Button(excluded.isEmpty ? "Select None" : "Select All") {
                        excluded = excluded.isEmpty ? Set(candidates.map(\.id)) : []
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }

            if let additional = plan?.additionalItems, !additional.isEmpty {
                Section {
                    ForEach(additional) { item in
                        PlanRow(
                            kind: item.isCask ? .cask : .formula,
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

    private func inclusion(of package: PackageType) -> Binding<Bool> {
        Binding(
            get: { !excluded.contains(package.id) },
            set: { isIncluded in
                if isIncluded {
                    excluded.remove(package.id)
                } else {
                    excluded.insert(package.id)
                }
            }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            VStack(alignment: .leading, spacing: Spacing.compact) {
                downloadSummary
                let pinned = store.pinnedOutdatedFormulae.map(\.name)
                if !pinned.isEmpty {
                    Label(
                        "Pinned, so skipped: \(pinned.formatted(.list(type: .and))). Unpin on the Updates page to include \(pinned.count == 1 ? "it" : "them").",
                        systemImage: "pin"
                    )
                    .fixedSize(horizontal: false, vertical: true)
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
                    let packages = selected
                    Task { await store.upgrade(packages) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(selected.isEmpty || store.isCheckingForUpdates || store.isUpgradingAll)
            }
        }
    }

    @ViewBuilder
    private var downloadSummary: some View {
        if plan != nil {
            if downloadBytes > 0 {
                Label(
                    "Up to \(downloadBytes.formatted(.byteCount(style: .file))) to download.",
                    systemImage: "arrow.down.circle"
                )
            }
        } else if let planError {
            Label("Couldn’t preview the download: \(planError)", systemImage: "exclamationmark.triangle")
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

    /// The checked packages' downloads plus the dependencies they pull in.
    private var downloadBytes: Int64 {
        let requested = selected.compactMap { plannedItem(for: $0)?.downloadBytes }
        let additional = plan?.additionalItems.compactMap(\.downloadBytes) ?? []
        return (requested + additional).reduce(0, +)
    }

    /// Running services whose formula is about to be upgraded.
    private var affectedServices: [String] {
        let names = Set(selected.filter { $0.kind == .formula }.map(\.identifier))
            .union(plan?.additionalItems.filter { !$0.isCask }.map(\.shortName) ?? [])
        return serviceStore.services
            .filter { $0.isRunning && names.contains($0.name) }
            .map(\.name)
    }

    private func plannedItem(for package: PackageType) -> UpgradePlan.Item? {
        plan?.items.first { $0.name == Self.planName(of: package) }
    }

    /// The name brew prints in its dry run — the fully qualified one.
    private static func planName(of package: PackageType) -> String {
        switch package {
        case .formula(let formula): formula.fullName
        case .cask(let cask): cask.qualifiedToken
        }
    }

    private func loadPlan() async {
        let packages = candidates
        do {
            plan = try await UpgradePlan.dryRun(
                formulae: packages.filter { $0.kind == .formula }.map(Self.planName),
                casks: packages.filter { $0.kind == .cask }.map(Self.planName)
            )
        } catch {
            guard !isOperationCancellation(error) else { return }
            planError = error.briefDescription
        }
    }
}

// MARK: - Row

private struct PlanRow: View {
    let kind: PackageKind
    let name: String
    let currentVersion: String
    let targetVersion: String
    let size: Int64?
    let isPlanLoading: Bool

    var body: some View {
        HStack(spacing: Spacing.item) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: IconSize.iconColumn)
                .help(kind == .formula ? "Formula" : "Cask")
                .accessibilityLabel(kind == .formula ? "Formula" : "Cask")
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
        .environment(AppStores())
}
