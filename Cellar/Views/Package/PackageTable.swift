import SwiftUI
import CellarCore

/// Installed packages of one kind in a sortable, multi-selection table with
/// a filter bar. The search field filters it without leaving the table.
struct PackageTable: View {
    let kind: PackageKind
    @Binding var filter: PackageFilter
    @Binding var sortOrder: [KeyPathComparator<PackageType>]
    let menu: (Set<PackageID>) -> PackageMenu
    let showDetails: (Set<PackageID>) -> Void
    let requestUninstall: ([PackageType]) -> Void

    @Environment(PackageStore.self) private var store

    private static let nameOrder = KeyPathComparator(\PackageType.name, comparator: String.StandardComparator.localizedStandard)
    private static let versionOrder = KeyPathComparator(\PackageType.version, comparator: String.StandardComparator.localizedStandard)

    /// Where each page remembers its sort order.
    static func sortStorage(for kind: PackageKind) -> SortOrderStorage<PackageType> {
        SortOrderStorage(
            key: SettingsKey.sortOrder(kind.rawValue),
            columns: ["name": nameOrder, "version": versionOrder],
            defaultColumn: "name"
        )
    }

    private var list: PackageListState { store.list(kind) }

    /// The installed-scope search text; the Homebrew scope searches elsewhere.
    private var query: String {
        list.searchScope == .installed ? list.trimmedQuery : ""
    }

    private var installed: [PackageType] { store.packages(kind) }

    private var rows: [PackageType] {
        installed
            .filter { filter.includes($0) && (query.isEmpty || $0.matches(query)) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        @Bindable var list = list
        let rows = rows

        VStack(spacing: 0) {
            filterBar(shownCount: rows.count)
            Divider()
            Table(rows, selection: $list.selection, sortOrder: $sortOrder) {
                TableColumn("Name", sortUsing: Self.nameOrder) { package in
                    PackageNameLabel(package: package)
                        .padding(.vertical, Spacing.textPair)
                }
                .width(min: 160, ideal: 280)

                TableColumn("Version", sortUsing: Self.versionOrder) { package in
                    Text(package.version)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Status") { package in
                    PackageStatusView(package: package, activityStore: store.activityStore)
                }
                .width(min: 80, ideal: 180)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .contextMenu(forSelectionType: PackageID.self, menu: menu, primaryAction: showDetails)
            .onDeleteCommand(perform: uninstallSelection)
            .onChange(of: sortOrder) { _, order in
                Self.sortStorage(for: kind).save(order)
            }
            .overlay {
                if rows.isEmpty {
                    emptyState
                }
            }
        }
    }

    // MARK: - Filter Bar

    private func filterBar(shownCount: Int) -> some View {
        HStack {
            Picker("Filter", selection: $filter) {
                ForEach(PackageFilter.filters(for: kind)) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Spacer()

            Text(countLabel(shownCount: shownCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.item)
    }

    /// "230 formulae", or "12 of 230 formulae" while filtered.
    private func countLabel(shownCount: Int) -> String {
        let total = installed.count
        let noun = kind.noun(count: total)
        return shownCount == total ? "\(total) \(noun)" : "\(shownCount) of \(total) \(noun)"
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if !query.isEmpty && filter == .all {
            EmptyStateView(
                title: "No Results",
                systemImage: "magnifyingglass",
                description: "No installed \(kind.noun(count: 2)) match “\(query)”.",
                actionTitle: "Search Homebrew",
                actionSystemImage: "magnifyingglass"
            ) {
                list.searchScope = .homebrew
            }
        } else {
            EmptyStateView(
                title: filter.emptyTitle(for: kind),
                systemImage: "line.3.horizontal.decrease.circle",
                actionTitle: "Show All",
                actionSystemImage: "line.3.horizontal.decrease.circle"
            ) {
                filter = .all
            }
        }
    }

    // MARK: - Actions

    /// Delete key: confirm uninstalling the selected packages.
    private func uninstallSelection() {
        let packages = list.selection.compactMap(store.package).filter { !store.isBusy($0) }
        guard !packages.isEmpty else { return }
        requestUninstall(packages)
    }
}

// MARK: - PackageNameLabel

/// The name with the description — or a cask's token — underneath.
struct PackageNameLabel: View {
    let package: PackageType

    private var subtitle: String? {
        if let description = package.description { return description }
        return package.name == package.identifier ? nil : package.identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.textPair) {
            Text(package.name)
                .fontWeight(.medium)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var filter = PackageFilter.all
    @Previewable @State var sortOrder = PackageTable.sortStorage(for: .formula).load()

    PackageTable(
        kind: .formula,
        filter: $filter,
        sortOrder: $sortOrder,
        menu: { _ in PackageMenu(packages: [], showDetails: {}, requestUninstall: { _ in }) },
        showDetails: { _ in },
        requestUninstall: { _ in }
    )
    .environment(AppStores())
    .frame(width: 700, height: 400)
}
