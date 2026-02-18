import SwiftUI
import CellarCore

struct FormulaListView: View {
    @Environment(PackageStore.self) private var store

    @State private var selectedFormulaID: Formula.ID?
    @State private var sortOrder: [KeyPathComparator<Formula>] = [
        KeyPathComparator(\.name)
    ]
    @State private var formulaToUninstall: Formula?
    @State private var formulaToInstall: Formula?
    @State private var installStream: AsyncThrowingStream<String, Error>?
    @State private var installTitle: String?

    private var isSearching: Bool {
        !store.searchQuery.isEmpty
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.formulae.isEmpty {
                LoadingView(message: "Loading Formulae\u{2026}")
            } else if let errorMessage = store.errorMessage, store.formulae.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await store.loadFormulae() }
                }
            } else if isSearching {
                searchResultsList
            } else if store.formulae.isEmpty {
                EmptyStateView(
                    title: "No Formulae",
                    systemImage: "shippingbox",
                    description: "Installed formulae will appear here."
                )
            } else {
                formulaTable
            }
        }
        .navigationTitle("Formulae")
        .searchable(text: $store.searchQuery, prompt: "Search formulae")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.isLoading) {
                    await store.loadFormulae(forceRefresh: true)
                }
            }
        }
        .task {
            await store.loadFormulae()
        }
        .task(id: store.searchQuery) {
            guard !store.searchQuery.isEmpty else {
                store.searchResultFormulae = []
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await store.searchRemoteFormulae()
        }
        .confirmationDialog(
            "Uninstall \(formulaToUninstall?.name ?? "")?",
            isPresented: Binding(
                get: { formulaToUninstall != nil },
                set: { if !$0 { formulaToUninstall = nil } }
            ),
            presenting: formulaToUninstall
        ) { formula in
            Button("Uninstall", role: .destructive) {
                Task { await store.uninstall(formula) }
            }
        } message: { formula in
            Text("This will remove \(formula.name) and its associated files.")
        }
        .confirmationDialog(
            "Install \(formulaToInstall?.name ?? "")?",
            isPresented: Binding(
                get: { formulaToInstall != nil },
                set: { if !$0 { formulaToInstall = nil } }
            ),
            presenting: formulaToInstall
        ) { formula in
            Button("Install") {
                let service = BrewService()
                installTitle = "Installing \(formula.name)"
                installStream = service.install(formula.name, isCask: false)
            }
        } message: { formula in
            Text("This will download and install \(formula.name) via Homebrew.")
        }
        .installProgressSheet(stream: $installStream, title: $installTitle) {
            Task { await store.loadFormulae(forceRefresh: true) }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List {
            if !store.filteredFormulae.isEmpty {
                Section {
                    ForEach(store.filteredFormulae) { formula in
                        installedFormulaRow(formula)
                            .contextMenu { formulaContextMenu(for: formula) }
                    }
                } header: {
                    CountedSectionHeader(title: "Installed", systemImage: "checkmark.circle.fill", count: store.filteredFormulae.count)
                }
            }

            if store.isSearchingFormulae {
                Section("Available") {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching Homebrew\u{2026}")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !store.availableFormulae.isEmpty {
                Section {
                    ForEach(store.availableFormulae) { formula in
                        availableFormulaRow(formula)
                    }
                } header: {
                    CountedSectionHeader(title: "Available", systemImage: "arrow.down.circle", count: store.availableFormulae.count)
                }
            }

            if store.filteredFormulae.isEmpty
                && store.availableFormulae.isEmpty
                && !store.isSearchingFormulae {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No formulae match \"\(store.searchQuery)\".")
                )
                .listRowSeparator(.hidden)
            }
        }
        .listRowSeparatorTint(.primary.opacity(0.05))
    }

    private func installedFormulaRow(_ formula: Formula) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
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

            Text(formula.version)
                .foregroundStyle(.secondary)
                .font(.body.monospaced())

            HStack(spacing: Spacing.related) {
                if formula.outdated {
                    StatusBadge(text: "Outdated", color: .orange)
                }
                if formula.pinned {
                    StatusBadge(text: "Pinned", color: .blue)
                }
            }
        }
    }

    private func availableFormulaRow(_ formula: Formula) -> some View {
        HStack {
            Text(formula.name)
                .fontWeight(.medium)

            Spacer()

            Button {
                formulaToInstall = formula
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Table

    private var formulaTable: some View {
        Table(store.filteredFormulae, selection: $selectedFormulaID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { formula in
                Text(formula.name)
                    .fontWeight(.medium)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Version", value: \.version) { formula in
                Text(formula.version)
                    .foregroundStyle(.secondary)
                    .font(.body.monospaced())
            }
            .width(min: 80, ideal: 120)

            TableColumn("Status") { formula in
                HStack(spacing: Spacing.related) {
                    if formula.outdated {
                        StatusBadge(text: "Outdated", color: .orange)
                    }
                    if formula.pinned {
                        StatusBadge(text: "Pinned", color: .blue)
                    }
                    if formula.isKegOnly {
                        StatusBadge(text: "Keg-only", color: .purple)
                    }
                    if formula.deprecated {
                        StatusBadge(text: "Deprecated", color: .red)
                    }
                }
            }
            .width(min: 80, ideal: 200)
        }
        .contextMenu(forSelectionType: Formula.ID.self) { selectedIDs in
            if let id = selectedIDs.first,
               let formula = store.filteredFormulae.first(where: { $0.id == id }) {
                formulaContextMenu(for: formula)
            }
        } primaryAction: { selectedIDs in
            // Double-click selects the row — no additional action needed
        }
        .onChange(of: sortOrder) { _, newOrder in
            store.formulae.sort(using: newOrder)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func formulaContextMenu(for formula: Formula) -> some View {
        if formula.outdated {
            Button {
                Task { await store.upgrade(formula) }
            } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
            }
        }

        if formula.pinned {
            Button {
                Task { await store.unpin(formula) }
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        } else {
            Button {
                Task { await store.pin(formula) }
            } label: {
                Label("Pin", systemImage: "pin")
            }
        }

        Divider()

        Button(role: .destructive) {
            formulaToUninstall = formula
        } label: {
            Label("Uninstall", systemImage: "trash")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FormulaListView()
            .environment(PackageStore())
    }
    .frame(width: 700, height: 500)
}
