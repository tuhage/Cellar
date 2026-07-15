import SwiftUI
import CellarCore

struct CaskListView: View {
    @Environment(PackageStore.self) private var store

    @State private var sortOrder: [KeyPathComparator<Cask>]
    @State private var isSearchPresented = false
    @State private var caskToUninstall: Cask?
    @State private var caskToInstall: Cask?

    init() {
        let defaults = UserDefaults.standard
        let order: SortOrder = defaults.object(forKey: "caskSortAscending") == nil
            || defaults.bool(forKey: "caskSortAscending") ? .forward : .reverse
        let comparator = defaults.string(forKey: "caskSortColumn") == "version"
            ? KeyPathComparator(\Cask.version, order: order)
            : KeyPathComparator(\Cask.token, order: order)
        _sortOrder = State(initialValue: [comparator])
    }

    private var isSearching: Bool {
        !store.caskSearchQuery.isEmpty
    }

    private var selectedCaskID: Binding<Cask.ID?> {
        Binding(
            get: { store.selectedCaskId },
            set: { store.selectedCaskId = $0 }
        )
    }

    private var selectedCask: Cask? {
        guard let id = store.selectedCaskId else { return nil }
        return store.casks.first { $0.id == id }
    }

    private var isInspectorPresented: Binding<Bool> {
        Binding(
            get: { selectedCask != nil },
            set: { if !$0 { store.selectedCaskId = nil } }
        )
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.casks.isEmpty {
                LoadingView(message: "Loading Casks\u{2026}")
            } else if let errorMessage = store.errorMessage, store.casks.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await store.loadCasks() }
                }
            } else if isSearching {
                searchResultsList
            } else if store.casks.isEmpty {
                EmptyStateView(
                    title: "No Casks",
                    systemImage: "macwindow",
                    description: "Installed casks will appear here.",
                    actionTitle: "Search Homebrew",
                    actionSystemImage: "magnifyingglass"
                ) {
                    isSearchPresented = true
                }
            } else {
                caskTable
            }
        }
        .navigationTitle("Casks")
        .searchable(text: $store.caskSearchQuery, isPresented: $isSearchPresented, prompt: "Search casks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.isLoading) {
                    await store.loadCasks(forceRefresh: true)
                }
            }
        }
        .task {
            await store.loadCasks()
        }
        .inspector(isPresented: isInspectorPresented) {
            if let selectedCask {
                PackageDetailView(package: .cask(selectedCask))
                    .inspectorColumnWidth(min: 360, ideal: 440, max: 560)
            }
        }
        .task(id: store.caskSearchQuery) {
            guard !store.caskSearchQuery.isEmpty else {
                store.searchResultCasks = []
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await store.searchRemoteCasks()
        }
        .confirmationDialog(
            "Uninstall \(caskToUninstall?.displayName ?? "")?",
            isPresented: Binding(
                get: { caskToUninstall != nil },
                set: { if !$0 { caskToUninstall = nil } }
            ),
            presenting: caskToUninstall
        ) { cask in
            Button("Uninstall", role: .destructive) {
                Task { await store.uninstall(cask) }
            }
            Button("Force Uninstall (ignore dependencies)", role: .destructive) {
                Task { await store.uninstall(cask, force: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { cask in
            Text("This will remove \(cask.displayName) and its associated files.")
        }
        .confirmationDialog(
            "Install \(caskToInstall?.displayName ?? "")?",
            isPresented: Binding(
                get: { caskToInstall != nil },
                set: { if !$0 { caskToInstall = nil } }
            ),
            presenting: caskToInstall
        ) { cask in
            Button("Install") {
                Task { await store.installCask(cask) }
            }
        } message: { cask in
            Text("This will download and install \(cask.displayName) via Homebrew.")
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List {
            if !store.filteredCasks.isEmpty {
                Section {
                    ForEach(store.filteredCasks) { cask in
                        installedCaskRow(cask)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedCaskId = cask.id }
                            .contextMenu { caskContextMenu(for: cask) }
                    }
                } header: {
                    CountedSectionHeader(title: "Installed", systemImage: "checkmark.circle.fill", count: store.filteredCasks.count)
                }
            }

            if store.isSearchingCasks {
                Section("Available") {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching Homebrew\u{2026}")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !store.availableCasks.isEmpty {
                Section {
                    ForEach(store.availableCasks) { cask in
                        availableCaskRow(cask)
                    }
                } header: {
                    CountedSectionHeader(title: "Available", systemImage: "arrow.down.circle", count: store.availableCasks.count)
                }
            }

            if store.filteredCasks.isEmpty
                && store.availableCasks.isEmpty
                && !store.isSearchingCasks {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No casks match \"\(store.caskSearchQuery)\".")
                )
                .listRowSeparator(.hidden)
            }
        }
    }

    private func installedCaskRow(_ cask: Cask) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(cask.displayName)
                    .fontWeight(.medium)

                if cask.displayName != cask.token {
                    Text(cask.token)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(cask.installed ?? cask.version)
                .foregroundStyle(.secondary)
                .font(.body.monospaced())

            HStack(spacing: Spacing.related) {
                if cask.outdated {
                    StatusBadge(text: "Outdated", color: .orange)
                }
                if cask.deprecated {
                    StatusBadge(text: "Deprecated", color: .red)
                }
            }
        }
    }

    private func availableCaskRow(_ cask: Cask) -> some View {
        HStack {
            Text(cask.token)
                .fontWeight(.medium)

            Spacer()

            Button {
                caskToInstall = cask
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Table

    private var caskTable: some View {
        Table(store.filteredCasks, selection: selectedCaskID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.token) { cask in
                VStack(alignment: .leading, spacing: Spacing.textPair) {
                    Text(cask.displayName)
                        .fontWeight(.medium)
                    if cask.displayName != cask.token {
                        Text(cask.token)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 120, ideal: 200)

            TableColumn("Version", value: \.version) { cask in
                Text(cask.installed ?? cask.version)
                    .foregroundStyle(.secondary)
                    .font(.body.monospaced())
            }
            .width(min: 80, ideal: 120)

            TableColumn("Auto Updates") { cask in
                if cask.autoUpdates {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .help("Updates automatically")
                } else {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                        .help("Managed by Homebrew")
                }
            }
            .width(min: 60, ideal: 100)

            TableColumn("Status") { cask in
                HStack(spacing: Spacing.related) {
                    if cask.outdated {
                        StatusBadge(text: "Outdated", color: .orange)
                    }
                    if cask.deprecated {
                        StatusBadge(text: "Deprecated", color: .red)
                    }
                }
            }
            .width(min: 60, ideal: 120)

            TableColumn("") { cask in
                Menu {
                    caskContextMenu(for: cask)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .help("Actions for \(cask.displayName)")
            }
            .width(28)
        }
        .contextMenu(forSelectionType: Cask.ID.self) { selectedIDs in
            if let id = selectedIDs.first,
               let cask = store.filteredCasks.first(where: { $0.id == id }) {
                caskContextMenu(for: cask)
            }
        } primaryAction: { _ in }
        .onChange(of: sortOrder) { _, newOrder in
            store.casks.sort(using: newOrder)
            persistSortOrder(newOrder)
        }
        .animation(AnimationToken.smooth, value: store.filteredCasks)
    }

    private func persistSortOrder(_ order: [KeyPathComparator<Cask>]) {
        guard let comparator = order.first else { return }
        UserDefaults.standard.set(comparator.order == .forward, forKey: "caskSortAscending")
        UserDefaults.standard.set(
            comparator.keyPath == \Cask.version ? "version" : "name",
            forKey: "caskSortColumn"
        )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func caskContextMenu(for cask: Cask) -> some View {
        if cask.outdated {
            Button {
                Task { await store.upgrade(cask) }
            } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
            }
        }

        Divider()

        Button(role: .destructive) {
            caskToUninstall = cask
        } label: {
            Label("Uninstall", systemImage: "trash")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaskListView()
            .environment(PackageStore())
    }
    .frame(width: 700, height: 500)
}
