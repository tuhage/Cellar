import SwiftUI
import CellarCore

struct OutdatedView: View {
    @Environment(PackageStore.self) private var store

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
            if store.isLoading && store.formulae.isEmpty && store.casks.isEmpty {
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
                    description: "Outdated packages will appear here."
                )
            } else {
                outdatedList
            }
        }
        .navigationTitle("Outdated")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search outdated packages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.isLoading) {
                    await store.loadAll(forceRefresh: true)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isConfirmingUpgradeAll = true
                } label: {
                    Label("Upgrade All", systemImage: "arrow.up.circle.fill")
                }
                .disabled(store.isUpgradingAll || (store.outdatedFormulae.isEmpty && store.outdatedCasks.isEmpty))
            }
        }
        .task {
            await store.loadAll()
        }
        .confirmationDialog(
            "Upgrade All Packages?",
            isPresented: $isConfirmingUpgradeAll,
            titleVisibility: .visible
        ) {
            Button("Upgrade All", role: .destructive) {
                upgradeAll()
            }
        } message: {
            let count = store.outdatedFormulae.count + store.outdatedCasks.count
            Text("Upgrade \(count) packages? This may take several minutes.")
        }
    }

    // MARK: - List

    private var outdatedList: some View {
        List {
            if !filteredFormulae.isEmpty {
                Section {
                    ForEach(filteredFormulae) { formula in
                        OutdatedPackageRow(
                            name: formula.name,
                            description: formula.desc,
                            currentVersion: formula.version,
                            targetVersion: "latest"
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
                            description: cask.desc,
                            currentVersion: cask.installed ?? cask.version,
                            targetVersion: cask.version
                        ) {
                            Task { await store.upgrade(cask) }
                        }
                    }
                } header: {
                    CountedSectionHeader(title: "Casks", systemImage: "macwindow", count: filteredCasks.count)
                }
            }
        }
        .overlay(alignment: .top) {
            if store.isUpgradingAll {
                upgradeAllBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(AnimationToken.smooth, value: store.isUpgradingAll)
    }

    // MARK: - Upgrade All Banner

    private var upgradeAllBanner: some View {
        HStack(spacing: Spacing.item) {
            ProgressView()
                .controlSize(.small)
            Text("Upgrading all packages\u{2026}")
                .font(.callout)

            Button("Cancel") {
                store.cancelUpgradeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.row)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.card))
        .shadow(radius: 4, y: 2)
        .padding(.top, Spacing.item)
    }

    // MARK: - Actions

    private func upgradeAll() {
        store.upgradeAll()
    }
}

// MARK: - Outdated Package Row

private struct OutdatedPackageRow: View {
    let name: String
    let description: String?
    let currentVersion: String
    let targetVersion: String
    let upgradeAction: () -> Void

    @Environment(ActivityStore.self) private var activityStore

    private var isUpgrading: Bool {
        activityStore.isActive(target: name)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
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

            Button {
                upgradeAction()
            } label: {
                if isUpgrading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Upgrade", systemImage: "arrow.up.circle")
                        .labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .controlSize(.small)
            .disabled(isUpgrading)
        }
        .padding(.vertical, Spacing.textPair)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        OutdatedView()
            .environment(PackageStore())
            .environment(ActivityStore())
    }
    .frame(width: 600, height: 500)
}
