import SwiftUI
import CellarCore

struct CaskListView: View {
    @Environment(PackageStore.self) private var store

    @State private var selectedCaskID: Cask.ID?
    @State private var sortOrder: [KeyPathComparator<Cask>] = [
        KeyPathComparator(\.token)
    ]
    @State private var caskToUninstall: Cask?
    @State private var installStream: AsyncThrowingStream<String, Error>?
    @State private var installTitle: String?

    private var isSearching: Bool {
        !store.searchQuery.isEmpty
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
                    description: "No installed casks found."
                )
            } else {
                caskTable
            }
        }
        .navigationTitle("Casks")
        .searchable(text: $store.searchQuery, prompt: "Search casks")
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
        .task(id: store.searchQuery) {
            guard !store.searchQuery.isEmpty else {
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
        } message: { cask in
            Text("This will remove \(cask.displayName) and its associated files.")
        }
        .installProgressSheet(stream: $installStream, title: $installTitle) {
            Task { await store.loadCasks(forceRefresh: true) }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List {
            if !store.filteredCasks.isEmpty {
                Section {
                    ForEach(store.filteredCasks) { cask in
                        installedCaskRow(cask)
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
                    description: Text("No casks match \"\(store.searchQuery)\".")
                )
                .listRowSeparator(.hidden)
            }
        }
    }

    private func installedCaskRow(_ cask: Cask) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
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

            HStack(spacing: 6) {
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
                let service = BrewService()
                installTitle = "Installing \(cask.displayName)"
                installStream = service.install(cask.token, isCask: true)
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Table

    private var caskTable: some View {
        Table(store.filteredCasks, selection: $selectedCaskID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.token) { cask in
                VStack(alignment: .leading, spacing: 2) {
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
                HStack(spacing: 6) {
                    if cask.outdated {
                        StatusBadge(text: "Outdated", color: .orange)
                    }
                    if cask.deprecated {
                        StatusBadge(text: "Deprecated", color: .red)
                    }
                }
            }
            .width(min: 60, ideal: 120)
        }
        .contextMenu(forSelectionType: Cask.ID.self) { selectedIDs in
            if let id = selectedIDs.first,
               let cask = store.filteredCasks.first(where: { $0.id == id }) {
                caskContextMenu(for: cask)
            }
        } primaryAction: { _ in }
        .onChange(of: sortOrder) { _, newOrder in
            store.casks.sort(using: newOrder)
        }
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
