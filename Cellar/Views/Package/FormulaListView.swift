import SwiftUI
import CellarCore

struct FormulaListView: View {
    @Environment(PackageStore.self) private var store

    @State private var selectedFormulaID: Formula.ID?
    @State private var sortOrder: [KeyPathComparator<Formula>] = [
        KeyPathComparator(\.name)
    ]

    private var isSearching: Bool {
        !store.searchQuery.isEmpty
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.formulae.isEmpty {
                LoadingView(message: "Loading formulae\u{2026}")
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
                    description: "No installed formulae found."
                )
            } else {
                formulaTable
            }
        }
        .navigationTitle("Formulae")
        .searchable(text: $store.searchQuery, prompt: "Search formulae")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadFormulae() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .task {
            if store.formulae.isEmpty {
                await store.loadFormulae()
            }
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
                    HStack {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                        Spacer()
                        Text("\(store.filteredFormulae.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
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
                    HStack {
                        Label("Available", systemImage: "arrow.down.circle")
                        Spacer()
                        Text("\(store.availableFormulae.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
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
    }

    private func installedFormulaRow(_ formula: Formula) -> some View {
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

            Text(formula.version)
                .foregroundStyle(.secondary)
                .font(.body.monospaced())

            HStack(spacing: 6) {
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
                Task { await store.installFormula(name: formula.name) }
            } label: {
                if store.installingPackages.contains(formula.name) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Install", systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(store.installingPackages.contains(formula.name))
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
                HStack(spacing: 6) {
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
            Task { await store.uninstall(formula) }
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
