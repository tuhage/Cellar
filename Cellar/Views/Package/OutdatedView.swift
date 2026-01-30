import SwiftUI
import CellarCore

struct OutdatedView: View {
    @Environment(PackageStore.self) private var store

    @State private var isUpgradingAll = false

    var body: some View {
        Group {
            if store.isLoading && store.formulae.isEmpty && store.casks.isEmpty {
                LoadingView(message: "Checking for updates\u{2026}")
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
                Button {
                    Task { await store.loadAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    upgradeAll()
                } label: {
                    Label("Upgrade All", systemImage: "arrow.up.circle.fill")
                }
                .disabled(isUpgradingAll || (store.outdatedFormulae.isEmpty && store.outdatedCasks.isEmpty))
            }
        }
        .task {
            if store.formulae.isEmpty && store.casks.isEmpty {
                await store.loadAll()
            }
        }
    }

    // MARK: - List

    private var outdatedList: some View {
        List {
            if !store.outdatedFormulae.isEmpty {
                Section {
                    ForEach(store.outdatedFormulae) { formula in
                        OutdatedFormulaRow(formula: formula) {
                            Task { await store.upgrade(formula) }
                        }
                    }
                } header: {
                    HStack {
                        Label("Formulae", systemImage: "terminal")
                        Spacer()
                        Text("\(store.outdatedFormulae.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            if !store.outdatedCasks.isEmpty {
                Section {
                    ForEach(store.outdatedCasks) { cask in
                        OutdatedCaskRow(cask: cask) {
                            Task { await store.upgrade(cask) }
                        }
                    }
                } header: {
                    HStack {
                        Label("Casks", systemImage: "macwindow")
                        Spacer()
                        Text("\(store.outdatedCasks.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if isUpgradingAll {
                upgradeAllBanner
            }
        }
    }

    // MARK: - Upgrade All Banner

    private var upgradeAllBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Upgrading all packages\u{2026}")
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4, y: 2)
        .padding(.top, 8)
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

// MARK: - Formula Row

private struct OutdatedFormulaRow: View {
    let formula: Formula
    let upgradeAction: () -> Void

    @State private var isUpgrading = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, 2)
    }
}

// MARK: - Cask Row

private struct OutdatedCaskRow: View {
    let cask: Cask
    let upgradeAction: () -> Void

    @State private var isUpgrading = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, 2)
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
