import SwiftUI
import CellarCore

struct CaskListView: View {
    @Environment(PackageStore.self) private var store

    @State private var selectedCaskID: Cask.ID?
    @State private var sortOrder: [KeyPathComparator<Cask>] = [
        KeyPathComparator(\.token)
    ]

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.casks.isEmpty {
                LoadingView(message: "Loading casks\u{2026}")
            } else if let errorMessage = store.errorMessage, store.casks.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await store.loadCasks() }
                }
            } else if store.filteredCasks.isEmpty {
                if store.searchQuery.isEmpty {
                    EmptyStateView(
                        title: "No Casks",
                        systemImage: "macwindow",
                        description: "No installed casks found."
                    )
                } else {
                    EmptyStateView(
                        title: "No Results",
                        systemImage: "magnifyingglass",
                        description: "No casks match \"\(store.searchQuery)\"."
                    )
                }
            } else {
                caskTable
            }
        }
        .navigationTitle("Casks")
        .searchable(text: $store.searchQuery, prompt: "Filter casks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadCasks() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .task {
            if store.casks.isEmpty {
                await store.loadCasks()
            }
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
            Task { await store.uninstall(cask) }
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
