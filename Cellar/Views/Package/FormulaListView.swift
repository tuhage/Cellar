import SwiftUI
import CellarCore

struct FormulaListView: View {
    @Environment(PackageStore.self) private var store

    @State private var selectedFormulaID: Formula.ID?
    @State private var sortOrder: [KeyPathComparator<Formula>] = [
        KeyPathComparator(\.name)
    ]

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            searchBar(prompt: "Filter formulae", text: $store.searchText)

            Divider()

            Group {
                if store.isLoading && store.formulae.isEmpty {
                    LoadingView(message: "Loading formulae\u{2026}")
                } else if let errorMessage = store.errorMessage, store.formulae.isEmpty {
                    ErrorView(message: errorMessage) {
                        Task { await store.loadFormulae() }
                    }
                } else if store.filteredFormulae.isEmpty {
                    if store.searchQuery.isEmpty && store.searchText.isEmpty {
                        EmptyStateView(
                            title: "No Formulae",
                            systemImage: "shippingbox",
                            description: "No installed formulae found."
                        )
                    } else {
                        EmptyStateView(
                            title: "No Results",
                            systemImage: "magnifyingglass",
                            description: "No formulae match \"\(store.searchText)\"."
                        )
                    }
                } else {
                    formulaTable
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Formulae")
        .onChange(of: store.searchText) {
            store.debounceSearch()
        }
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
    }

    // MARK: - Search Bar

    private func searchBar(prompt: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                    store.debounceSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
