import SwiftUI
import CellarCore

/// What Homebrew offers for the page's search, installed packages marked.
/// Rows select like installed ones, so the inspector can show and install
/// them.
struct PackageSearchResults: View {
    let kind: PackageKind
    let menu: (Set<PackageID>) -> PackageMenu
    let showDetails: (Set<PackageID>) -> Void

    @Environment(PackageStore.self) private var store

    private var list: PackageListState { store.list(kind) }

    private var isQueryTooShort: Bool {
        list.trimmedQuery.count < PackageStore.minimumSearchLength
    }

    /// Results, with installed packages replaced by their installed version.
    private var results: [PackageType] {
        guard !isQueryTooShort else { return [] }
        return list.searchResults.map { store.package($0.id) ?? $0 }
    }

    var body: some View {
        @Bindable var list = list
        let results = results

        List(selection: $list.selection) {
            if !results.isEmpty {
                Section {
                    ForEach(results) { package in
                        SearchResultRow(package: package)
                    }
                } header: {
                    CountedSectionHeader(
                        title: list.isSearching ? "Searching Homebrew\u{2026}" : "Homebrew",
                        systemImage: "magnifyingglass",
                        count: results.count
                    )
                } footer: {
                    if results.contains(where: \.isNameOnly) {
                        Text("Only names are shown past the first \(PackageStore.searchDetailLimit) results. Select one to see its details.")
                    }
                }
            }
        }
        .contextMenu(forSelectionType: PackageID.self, menu: menu, primaryAction: showDetails)
        .overlay {
            if results.isEmpty {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isQueryTooShort {
            EmptyStateView(
                title: "Keep Typing",
                systemImage: "magnifyingglass",
                description: "Type at least \(PackageStore.minimumSearchLength) characters to search Homebrew."
            )
        } else if let error = list.searchError, !list.isSearching {
            ErrorView(message: "Couldn’t search Homebrew.", suggestion: error) {
                Task { await store.searchHomebrew(kind) }
            }
        } else if list.isSearching || list.resultsQuery != list.trimmedQuery {
            LoadingView(message: "Searching Homebrew\u{2026}")
        } else {
            ContentUnavailableView.search(text: list.trimmedQuery)
        }
    }
}

// MARK: - Row

private struct SearchResultRow: View {
    let package: PackageType

    var body: some View {
        HStack(spacing: Spacing.sectionContent) {
            PackageNameLabel(package: package)

            Spacer(minLength: Spacing.item)

            if !package.isNameOnly {
                Text(package.version)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if package.isInstalled {
                StatusBadge(text: "Installed", color: .green, icon: "checkmark")
            } else {
                PackageInstallButton(package: package)
            }
        }
        .padding(.vertical, Spacing.textPair)
    }
}

/// Install, or its progress while it runs.
struct PackageInstallButton: View {
    let package: PackageType

    @Environment(PackageStore.self) private var store
    @Environment(ActivityStore.self) private var activityStore

    var body: some View {
        if let activity = PackageActivity(package, activityStore: activityStore) {
            PackageActivityLabel(activity: activity)
        } else {
            Button {
                Task { await store.install(package) }
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Install \(package.name) — you can follow and cancel it in Activity")
        }
    }
}

// MARK: - Preview

#Preview {
    PackageSearchResults(
        kind: .formula,
        menu: { _ in PackageMenu(packages: [], showDetails: {}, requestUninstall: { _ in }) },
        showDetails: { _ in }
    )
    .environment(AppStores())
    .frame(width: 600, height: 400)
}
