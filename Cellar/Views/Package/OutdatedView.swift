import SwiftUI
import CellarCore

struct OutdatedView: View {
    @Environment(PackageStore.self) private var store

    @State private var isUpgradingAll = false
    @State private var isConfirmingUpgradeAll = false

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
                    description: "All packages are at their latest versions."
                )
            } else {
                outdatedList
            }
        }
        .navigationTitle("Outdated")
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
                .disabled(isUpgradingAll || (store.outdatedFormulae.isEmpty && store.outdatedCasks.isEmpty))
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
            if !store.outdatedFormulae.isEmpty {
                Section {
                    ForEach(store.outdatedFormulae) { formula in
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
                    CountedSectionHeader(title: "Formulae", systemImage: "terminal", count: store.outdatedFormulae.count)
                }
            }

            if !store.outdatedCasks.isEmpty {
                Section {
                    ForEach(store.outdatedCasks) { cask in
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
                    CountedSectionHeader(title: "Casks", systemImage: "macwindow", count: store.outdatedCasks.count)
                }
            }
        }
        .overlay(alignment: .top) {
            if isUpgradingAll {
                upgradeAllBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(AnimationToken.smooth, value: isUpgradingAll)
    }

    // MARK: - Upgrade All Banner

    private var upgradeAllBanner: some View {
        HStack(spacing: Spacing.item) {
            ProgressView()
                .controlSize(.small)
            Text("Upgrading all packages\u{2026}")
                .font(.callout)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.row)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.card))
        .shadow(radius: 4, y: 2)
        .padding(.top, Spacing.item)
    }

    // MARK: - Actions

    private func upgradeAll() {
        isUpgradingAll = true
        Task {
            let service = BrewService()
            do {
                for try await _ in service.upgradeAll() {}
            } catch {
                // Store will pick up errors on next reload
            }
            await store.loadAll()
            isUpgradingAll = false
        }
    }
}

// MARK: - Outdated Package Row

private struct OutdatedPackageRow: View {
    let name: String
    let description: String?
    let currentVersion: String
    let targetVersion: String
    let upgradeAction: () -> Void

    @State private var isUpgrading = false

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
                isUpgrading = true
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
    }
    .frame(width: 600, height: 500)
}
