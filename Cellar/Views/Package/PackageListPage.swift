import SwiftUI
import CellarCore

/// The Formulae and Casks pages: installed packages in a sortable table,
/// filtered by the search field, or Homebrew's search results when the
/// Homebrew scope is chosen.
struct PackageListPage: View {
    let kind: PackageKind

    @Environment(PackageStore.self) private var store

    @State private var sortOrder: [KeyPathComparator<PackageType>]
    @State private var filter = PackageFilter.all
    @State private var isSearchPresented = false
    @State private var uninstallRequest: UninstallRequest?
    @AppStorage(SettingsKey.showsInspector(.package)) private var showsInspector = true

    init(kind: PackageKind) {
        self.kind = kind
        _sortOrder = State(initialValue: PackageTable.sortStorage(for: kind).load())
    }

    private var list: PackageListState { store.list(kind) }

    private var isShowingHomebrewResults: Bool {
        list.searchScope == .homebrew && !list.trimmedQuery.isEmpty
    }

    /// The selected package, installed or from the search results.
    private var selectedPackage: PackageType? {
        list.singleSelection.flatMap(store.packageOrSearchResult)
    }

    var body: some View {
        @Bindable var list = list

        content
            .navigationTitle(kind.title)
            .dataFreshness(store.lastUpdated)
            .loadErrorBanner(for: store) { await store.loadAll(forceRefresh: true) }
            .searchable(text: $list.searchQuery, isPresented: $isSearchPresented, prompt: "Search \(kind.noun(count: 2))")
            .searchScopes($list.searchScope) {
                Text("Installed").tag(PackageListState.SearchScope.installed)
                Text("Homebrew").tag(PackageListState.SearchScope.homebrew)
            }
            .pageRefresh(
                help: "Reload installed \(kind.noun(count: 2)). Use Check for Updates on the Updates page to find new versions.",
                isLoading: store.isLoading
            ) {
                await store.loadAll(forceRefresh: true)
            }
            .packageSelection(selectedPackage, uninstallRequest: $uninstallRequest)
            .task { await store.loadAll() }
            .task(id: SearchTrigger(query: list.trimmedQuery, scope: list.searchScope)) {
                list.prepareSearch()
                guard list.isSearching else { return }
                try? await Task.sleep(for: PackageStore.searchDelay)
                guard !Task.isCancelled else { return }
                await store.searchHomebrew(kind)
            }
            .onAppear {
                // Arriving from elsewhere with a package selected shows it.
                if list.singleSelection != nil { showsInspector = true }
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.packages(kind).isEmpty {
            LoadingView(message: "Loading \(kind.title)\u{2026}")
        } else if let errorMessage = store.errorMessage, store.lastUpdated == nil {
            ErrorView(message: errorMessage) {
                Task { await store.loadAll(forceRefresh: true) }
            }
        } else if isShowingHomebrewResults {
            PackageSearchResults(kind: kind, menu: menu, showDetails: showDetails)
        } else if store.packages(kind).isEmpty {
            EmptyStateView(
                title: "No \(kind.title)",
                systemImage: kind.systemImage,
                description: "Installed \(kind.noun(count: 2)) will appear here.",
                actionTitle: "Search Homebrew",
                actionSystemImage: "magnifyingglass"
            ) {
                store.list(kind).searchScope = .homebrew
                isSearchPresented = true
            }
        } else {
            PackageTable(kind: kind, filter: $filter, sortOrder: $sortOrder, menu: menu, showDetails: showDetails) {
                uninstallRequest = UninstallRequest(packages: $0)
            }
        }
    }

    // MARK: - Actions

    private func menu(for ids: Set<PackageID>) -> PackageMenu {
        PackageMenu(packages: ids.compactMap(store.packageOrSearchResult), showDetails: { showDetails(ids) }) { uninstallRequest = $0 }
    }

    /// Double-click or Return: show the clicked package in the inspector.
    private func showDetails(_ ids: Set<PackageID>) {
        guard let id = ids.first else { return }
        list.select(id)
        showsInspector = true
    }
}

/// Re-runs the search when either the text or the scope changes.
private struct SearchTrigger: Hashable {
    let query: String
    let scope: PackageListState.SearchScope
}

// MARK: - PackageFilter

/// The filter above the installed table.
enum PackageFilter: String, CaseIterable, Identifiable {
    case all
    case outdated
    case pinned
    case installedOnRequest
    case dependencies
    case autoUpdating

    var id: String { rawValue }

    static func filters(for kind: PackageKind) -> [PackageFilter] {
        switch kind {
        case .formula: [.all, .outdated, .pinned, .installedOnRequest, .dependencies]
        case .cask: [.all, .outdated, .autoUpdating]
        }
    }

    var title: String {
        switch self {
        case .all: "All"
        case .outdated: "Outdated"
        case .pinned: "Pinned"
        case .installedOnRequest: "Installed by Me"
        case .dependencies: "Dependencies"
        case .autoUpdating: "Auto-updating"
        }
    }

    func includes(_ package: PackageType) -> Bool {
        switch (self, package) {
        case (.all, _): true
        case (.outdated, _): package.isOutdated
        case (.pinned, _): package.isPinned
        case (.installedOnRequest, .formula(let formula)): formula.installedOnRequest
        case (.dependencies, .formula(let formula)): !formula.installedOnRequest
        case (.autoUpdating, .cask(let cask)): cask.autoUpdates
        default: false
        }
    }

    /// "No pinned formulae" — when nothing passes the filter.
    func emptyTitle(for kind: PackageKind) -> String {
        let noun = kind.noun(count: 2)
        return switch self {
        case .all: "No \(kind.title)"
        case .outdated: "No outdated \(noun)"
        case .pinned: "No pinned \(noun)"
        case .installedOnRequest: "No \(noun) installed by you"
        case .dependencies: "No \(noun) installed as dependencies"
        case .autoUpdating: "No auto-updating \(noun)"
        }
    }
}

// MARK: - Preview

#Preview("Formulae") {
    NavigationStack {
        PackageListPage(kind: .formula)
    }
    .environment(AppStores())
    .frame(width: 800, height: 500)
}

#Preview("Casks") {
    NavigationStack {
        PackageListPage(kind: .cask)
    }
    .environment(AppStores())
    .frame(width: 800, height: 500)
}
