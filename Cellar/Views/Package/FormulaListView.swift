import SwiftUI
import CellarCore

struct FormulaListView: View {
    @Environment(PackageStore.self) private var store

    @State private var sortOrder: [KeyPathComparator<Formula>]
    @State private var isSearchPresented = false
    @State private var formulaToUninstall: Formula?
    @State private var formulaToInstall: Formula?
    @State private var scope: FormulaScope = .all

    init() {
        let defaults = UserDefaults.standard
        let order: SortOrder = defaults.object(forKey: "formulaSortAscending") == nil
            || defaults.bool(forKey: "formulaSortAscending") ? .forward : .reverse
        let comparator = defaults.string(forKey: "formulaSortColumn") == "version"
            ? KeyPathComparator(\Formula.version, order: order)
            : KeyPathComparator(\Formula.name, order: order)
        _sortOrder = State(initialValue: [comparator])
    }

    private var isSearching: Bool {
        !store.formulaSearchQuery.isEmpty
    }

    private var selectedFormulaID: Binding<Formula.ID?> {
        Binding(
            get: { store.selectedFormulaId },
            set: { store.selectedFormulaId = $0 }
        )
    }

    private var selectedFormula: Formula? {
        guard let id = store.selectedFormulaId else { return nil }
        return store.formulae.first { $0.id == id }
    }

    private var scopedFormulae: [Formula] {
        switch scope {
        case .all: store.filteredFormulae
        case .outdated: store.filteredFormulae.filter(\.outdated)
        case .pinned: store.filteredFormulae.filter(\.pinned)
        case .kegOnly: store.filteredFormulae.filter(\.isKegOnly)
        }
    }

    private var isInspectorPresented: Binding<Bool> {
        Binding(
            get: { selectedFormula != nil },
            set: { if !$0 { store.selectedFormulaId = nil } }
        )
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.formulae.isEmpty {
                LoadingView(message: "Loading Formulae\u{2026}")
            } else if let errorMessage = store.errorMessage, store.formulae.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await store.loadAll() }
                }
            } else if isSearching {
                searchResultsList
            } else if store.formulae.isEmpty {
                EmptyStateView(
                    title: "No Formulae",
                    systemImage: "shippingbox",
                    description: "Installed formulae will appear here.",
                    actionTitle: "Search Homebrew",
                    actionSystemImage: "magnifyingglass"
                ) {
                    isSearchPresented = true
                }
            } else {
                formulaTable
            }
        }
        .navigationTitle("Formulae")
        .searchable(text: $store.formulaSearchQuery, isPresented: $isSearchPresented, prompt: "Search formulae")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.isLoading) {
                    await store.loadAll(forceRefresh: true)
                }
            }
        }
        .task {
            await store.loadAll()
        }
        .inspector(isPresented: isInspectorPresented) {
            if let selectedFormula {
                PackageDetailView(package: .formula(selectedFormula))
                    .inspectorColumnWidth(min: 360, ideal: 440, max: 560)
            }
        }
        .task(id: store.formulaSearchQuery) {
            guard !store.formulaSearchQuery.isEmpty else {
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
            Button("Force Uninstall (ignore dependencies)", role: .destructive) {
                Task { await store.uninstall(formula, force: true) }
            }
            Button("Cancel", role: .cancel) {}
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
                Task { await store.installFormula(name: formula.name) }
            }
        } message: { formula in
            Text("This will download and install \(formula.name) via Homebrew.")
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List {
            if !store.filteredFormulae.isEmpty {
                Section {
                    ForEach(store.filteredFormulae) { formula in
                        installedFormulaRow(formula)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedFormulaId = formula.id }
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
                    description: Text("No formulae match \"\(store.formulaSearchQuery)\".")
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
        VStack(spacing: 0) {
            HStack {
                Picker("Package filter", selection: $scope) {
                    ForEach(FormulaScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                Spacer()

                Text("\(scopedFormulae.count) installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.vertical, Spacing.item)

            Divider()

            Table(scopedFormulae, selection: selectedFormulaID, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { formula in
                    Text(formula.name)
                        .fontWeight(.medium)
                        .padding(.vertical, Spacing.textPair)
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
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .contextMenu(forSelectionType: Formula.ID.self) { selectedIDs in
                if let id = selectedIDs.first,
                   let formula = store.filteredFormulae.first(where: { $0.id == id }) {
                    formulaContextMenu(for: formula)
                }
            } primaryAction: { _ in }
            .onChange(of: sortOrder) { _, newOrder in
                store.formulae.sort(using: newOrder)
                persistSortOrder(newOrder)
            }
        }
        .animation(AnimationToken.smooth, value: scopedFormulae)
    }

    private func persistSortOrder(_ order: [KeyPathComparator<Formula>]) {
        guard let comparator = order.first else { return }
        UserDefaults.standard.set(comparator.order == .forward, forKey: "formulaSortAscending")
        UserDefaults.standard.set(
            comparator.keyPath == \Formula.version ? "version" : "name",
            forKey: "formulaSortColumn"
        )
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

private enum FormulaScope: String, CaseIterable, Identifiable {
    case all, outdated, pinned, kegOnly

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All"
        case .outdated: "Outdated"
        case .pinned: "Pinned"
        case .kegOnly: "Keg-only"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FormulaListView()
            .environment(AppStores())
    }
    .frame(width: 700, height: 500)
}
