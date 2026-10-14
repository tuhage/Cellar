import SwiftUI
import CellarCore

struct TapListView: View {
    @Environment(TapStore.self) private var store
    @Environment(PackageStore.self) private var packageStore
    @Environment(ActivityStore.self) private var activityStore

    @State private var selectedTapID: Tap.ID?
    @State private var isAddingTap = false
    @State private var tapToRemove: TapUsage?
    @State private var sortOrder = Self.sortStorage.load()
    @AppStorage("tapInspectorPresented") private var isInspectorPresented = false

    private static let sortStorage = SortOrderStorage<TapUsage>(
        key: "tapSortOrder",
        columns: [
            "name": KeyPathComparator(\.name),
            "installed": KeyPathComparator(\.installedCount),
            "formulae": KeyPathComparator(\.formulaCount),
            "casks": KeyPathComparator(\.caskCount),
            "source": KeyPathComparator(\.sourceTitle),
            "lastCommit": KeyPathComparator(\.lastCommitAge),
        ],
        defaultColumn: "name"
    )

    /// Every listed tap with the installed packages it provides.
    private var usages: [TapUsage] {
        TapUsage.usages(of: store.filteredTaps, formulae: packageStore.formulae, casks: packageStore.casks)
    }

    private var selectedUsage: TapUsage? {
        usages.first { $0.id == selectedTapID }
    }

    var body: some View {
        @Bindable var store = store

        content
            .loadErrorBanner(for: store) { await store.load(forceRefresh: true) }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let operation = store.runningOperation {
                    RunningOperationBar(operation: operation)
                }
            }
            .navigationTitle("Taps")
            .dataFreshness(store.lastUpdated)
            .searchable(text: $store.searchQuery, prompt: "Filter taps")
            .toolbar { toolbar }
            .pageInspector(isPresented: $isInspectorPresented, widthKey: "tapInspectorWidth") {
                inspector
            }
            .task { await store.load() }
            .focusedSceneValue(\.pageRefresh, AsyncAction { await store.load(forceRefresh: true) })
            .sheet(isPresented: $isAddingTap) {
                AddTapSheet()
            }
            .confirmationDialog(
                "Untap \(tapToRemove?.name ?? "")?",
                isPresented: Binding(
                    get: { tapToRemove != nil },
                    set: { if !$0 { tapToRemove = nil } }
                ),
                presenting: tapToRemove
            ) { usage in
                untapButtons(for: usage)
            } message: { usage in
                Text(untapMessage(for: usage))
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.taps.isEmpty {
            LoadingView(message: "Loading Taps\u{2026}")
        } else if let errorMessage = store.errorMessage, store.taps.isEmpty {
            ErrorView(message: errorMessage) {
                Task { await store.load(forceRefresh: true) }
            }
        } else if store.taps.isEmpty {
            EmptyStateView(
                title: "No Taps",
                systemImage: "spigot",
                description: "Taps add formulae and casks from outside Homebrew’s main repositories.",
                actionTitle: "Add Tap",
                actionSystemImage: "plus"
            ) {
                isAddingTap = true
            }
        } else if store.filteredTaps.isEmpty {
            ContentUnavailableView.search(text: store.searchQuery)
        } else {
            tapTable
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isAddingTap = true
            } label: {
                Label("Add Tap", systemImage: "plus")
            }
            .help("Add a tap")
        }

        ToolbarItem(placement: .primaryAction) {
            RefreshToolbarButton(isLoading: store.isLoading) {
                await store.load(forceRefresh: true)
            }
        }

        ToolbarItem(placement: .status) {
            if !store.taps.isEmpty {
                Text("\(store.taps.count) taps")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.item)
            }
        }
    }

    // MARK: - Table

    private var tapTable: some View {
        let rows = usages.sorted(using: sortOrder)
        return Table(rows, selection: $selectedTapID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { usage in
                HStack(spacing: Spacing.related) {
                    Text(usage.name)
                        .fontWeight(.medium)
                        .padding(.vertical, Spacing.textPair)
                    if usage.tap.official {
                        StatusBadge(text: "Official", color: .blue, icon: "checkmark.seal")
                    }
                }
            }
            .width(min: 140, ideal: 220)

            TableColumn("Installed", value: \.installedCount) { usage in
                countText(usage.installedCount)
                    .help("Installed packages that come from this tap")
            }
            .width(min: 60, ideal: 80)

            TableColumn("Formulae", value: \.formulaCount) { usage in
                countText(usage.formulaCount)
                    .help("Formulae this tap offers")
            }
            .width(min: 60, ideal: 80)

            TableColumn("Casks", value: \.caskCount) { usage in
                countText(usage.caskCount)
                    .help("Casks this tap offers")
            }
            .width(min: 60, ideal: 80)

            TableColumn("Source", value: \.sourceTitle) { usage in
                Label(usage.sourceTitle, systemImage: usage.tap.installed ? "externaldrive" : "cloud")
                    .font(.callout)
                    .help(usage.sourceHelp)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Last Commit", value: \.lastCommitAge) { usage in
                Text(usage.tap.lastCommit.isEmpty ? "—" : usage.tap.lastCommit)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .contextMenu(forSelectionType: Tap.ID.self) { selectedIDs in
            if let usage = rows.first(where: { selectedIDs.contains($0.id) }) {
                tapContextMenu(for: usage)
            }
        } primaryAction: { selectedIDs in
            selectedTapID = selectedIDs.first
            isInspectorPresented = true
        }
        .onDeleteCommand {
            if let selectedUsage, canUntap(selectedUsage) {
                tapToRemove = selectedUsage
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            Self.sortStorage.save(newOrder)
        }
    }

    private func countText(_ count: Int) -> some View {
        Text("\(count)")
            .monospacedDigit()
            .foregroundStyle(count > 0 ? .primary : .tertiary)
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspector: some View {
        if let selectedUsage {
            TapInspector(
                usage: selectedUsage,
                canUntap: canUntap(selectedUsage),
                untap: { tapToRemove = selectedUsage }
            )
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "spigot",
                description: Text("Select a tap to see its packages and repository.")
            )
        }
    }

    // MARK: - Actions

    /// Taps served by the Homebrew API have no clone to remove.
    private func canUntap(_ usage: TapUsage) -> Bool {
        usage.tap.installed && !activityStore.isActive(.tap(usage.name))
    }

    @ViewBuilder
    private func tapContextMenu(for usage: TapUsage) -> some View {
        Button {
            selectedTapID = usage.id
            isInspectorPresented = true
        } label: {
            Label("Show Packages", systemImage: "sidebar.trailing")
        }

        if let url = usage.tap.githubURL {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("Open on GitHub", systemImage: "arrow.up.right.square")
            }
        }

        Divider()

        Button(role: .destructive) {
            tapToRemove = usage
        } label: {
            Label("Untap\u{2026}", systemImage: "trash")
        }
        .disabled(!canUntap(usage))
    }

    @ViewBuilder
    private func untapButtons(for usage: TapUsage) -> some View {
        if usage.installedCount == 0 {
            Button("Untap", role: .destructive) {
                Task { await store.removeTap(usage.tap) }
            }
        } else {
            Button("Untap Anyway (--force)", role: .destructive) {
                Task { await store.removeTap(usage.tap, force: true) }
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    private func untapMessage(for usage: TapUsage) -> String {
        let installed = usage.installedFormulae + usage.installedCasks
        guard !installed.isEmpty else {
            return "Its formulae and casks will no longer be available. You can tap it again later."
        }
        return "\(installed.briefList()) \(installed.count == 1 ? "comes" : "come") from this tap, "
            + "so Homebrew won’t untap it on its own. Untapping anyway keeps them installed, "
            + "but they can’t be upgraded or reinstalled until you tap it again."
    }
}

// MARK: - Source

/// `nonisolated` so the sort key path is `Sendable`.
nonisolated extension TapUsage {
    /// Core taps come from the Homebrew API; others are git clones.
    var sourceTitle: String { tap.installed ? "Local" : "API" }

    var sourceHelp: String {
        tap.installed ? "Cloned to \(tap.path)" : "Served by the Homebrew API — there’s no local clone"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TapListView()
            .environment(AppStores())
    }
    .frame(width: 900, height: 500)
}
