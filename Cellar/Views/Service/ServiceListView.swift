import SwiftUI
import CellarCore

struct ServiceListView: View {
    @Environment(ServiceStore.self) private var store
    @Environment(ServiceMetricsStore.self) private var metrics
    @Environment(PackageStore.self) private var packageStore
    @Environment(ActivityStore.self) private var activityStore

    @State private var sortOrder = Self.sortStorage.load()
    @AppStorage("services.columns") private var columnCustomization = TableColumnCustomization<ServiceRow>()
    @AppStorage("services.showsInspector") private var showsInspector = true
    @State private var showsOnlyFailed = false
    @State private var pendingAction: PendingServiceAction?

    private static let sortStorage = SortOrderStorage<ServiceRow>(
        key: "services.sort",
        columns: [
            "name": KeyPathComparator(\.name),
            "status": KeyPathComparator(\.status),
            "cpu": KeyPathComparator(\.cpuPercent),
            "memory": KeyPathComparator(\.memoryBytes),
            "uptime": KeyPathComparator(\.startedAt),
            "pid": KeyPathComparator(\.pid),
            "user": KeyPathComparator(\.user),
        ],
        defaultColumn: "name"
    )

    private var isFilteringFailed: Bool {
        showsOnlyFailed && store.failedCount > 0
    }

    private var rows: [ServiceRow] {
        store.visibleServices
            .filter { !isFilteringFailed || $0.isError }
            .map { ServiceRow(service: $0, usage: metrics.usage(for: $0), startedAt: store.startDate(of: $0)) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        content
            .navigationTitle("Services")
            .dataFreshness(store.lastUpdated)
            .loadErrorBanner(for: store) { await store.load(forceRefresh: true) }
            .safeAreaInset(edge: .top, spacing: 0) { restartBanner }
            .toolbar { toolbarContent }
            .task { await store.load() }
            .task { await metrics.monitor { store.services } }
            .inspector(isPresented: isInspectorPresented) {
                if let service = store.selectedService {
                    ServiceDetailView(service: service, pendingAction: $pendingAction)
                        .id(service.name)
                        .inspectorColumnWidth(min: 360, ideal: 420, max: 540)
                }
            }
            .confirmingServiceAction($pendingAction)
            .focusedSceneValue(\.pageRefresh, AsyncAction { await store.load(forceRefresh: true) })
            .focusedSceneValue(\.selectedService, selectedServiceCommands)
            .onChange(of: sortOrder) { _, newOrder in Self.sortStorage.save(newOrder) }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.services.isEmpty {
            LoadingView(message: "Loading Services\u{2026}")
        } else if let errorMessage = store.errorMessage, store.services.isEmpty {
            ErrorView(message: errorMessage) {
                Task { await store.load(forceRefresh: true) }
            }
        } else if store.services.isEmpty {
            EmptyStateView(
                title: "No Services",
                systemImage: "gearshape.2",
                description: "Formulae that run in the background, such as databases, appear here.",
                actionTitle: "Check Again"
            ) {
                Task { await store.load(forceRefresh: true) }
            }
        } else if store.visibleServices.isEmpty {
            EmptyStateView(
                title: "All Services Hidden",
                systemImage: "eye.slash",
                description: "You hid every service from this list.",
                actionTitle: "Show Hidden Services",
                actionSystemImage: "eye"
            ) {
                store.showsHiddenServices = true
            }
        } else {
            serviceTable
        }
    }

    // MARK: - Inspector

    /// Selecting a row shows the inspector unless the user closed it;
    /// double-click or Return opens it again.
    private var isInspectorPresented: Binding<Bool> {
        Binding(
            get: { showsInspector && store.selectedService != nil },
            set: { showsInspector = $0 }
        )
    }

    private var selectedServiceCommands: SelectedServiceCommands? {
        guard let service = store.selectedService else { return nil }
        return SelectedServiceCommands(
            name: service.name,
            isRunning: service.isRunning,
            isBusy: activityStore.isActive(.package(service.name)),
            start: { Task { await store.start(service) } },
            stop: { Task { await store.stop(service) } },
            restart: { Task { await store.restart(service) } }
        )
    }

    // MARK: - Banner

    /// Services upgraded while running still execute the old build.
    @ViewBuilder
    private var restartBanner: some View {
        let services = store.servicesNeedingRestart(formulae: packageStore.formulae)
        if !services.isEmpty {
            RestartServicesBanner(
                services: services,
                isRestarting: services.contains { activityStore.isActive(.package($0.name)) }
            ) {
                Task { await store.restart(services) }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .status) {
            if store.runningCount > 0 {
                CountPill(text: "\(store.runningCount) running", color: .green)
            }
            if store.failedCount > 0 {
                Toggle(isOn: $showsOnlyFailed) {
                    CountPill(text: "\(store.failedCount) failed", color: .red, isSelected: isFilteringFailed)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .help(isFilteringFailed ? "Show all services" : "Show only failed services")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            filterMenu
        }

        ToolbarItem(placement: .primaryAction) {
            RefreshToolbarButton(isLoading: store.isLoading) {
                await store.load(forceRefresh: true)
            }
        }
    }

    private var filterMenu: some View {
        @Bindable var store = store
        let isFiltering = isFilteringFailed || (store.hiddenCount > 0 && !store.showsHiddenServices)

        return Menu {
            Toggle("Show Hidden Services", isOn: $store.showsHiddenServices)
                .disabled(store.hiddenCount == 0)
            Toggle("Show Only Failed Services", isOn: $showsOnlyFailed)
                .disabled(store.failedCount == 0)

            if store.hiddenCount > 0 {
                Divider()
                Button("Unhide All (\(store.hiddenCount))") {
                    store.unhideAll()
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
            )
        }
        .help("Filter services")
    }

    // MARK: - Table

    private var serviceTable: some View {
        @Bindable var store = store

        return Table(
            rows,
            selection: $store.selectedServiceId,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
            TableColumn("Name", value: \.name) { row in
                Text(row.name)
                    .fontWeight(.medium)
                    .padding(.vertical, Spacing.textPair)
            }
            .width(min: 120, ideal: 200)
            .customizationID("name")
            .disabledCustomizationBehavior(.visibility)

            TableColumn("Status", value: \.status) { row in
                ServiceStatusBadge(service: row.service, isBusy: activityStore.isActive(.package(row.name)))
            }
            .width(min: 90, ideal: 110)
            .customizationID("status")

            TableColumn("CPU", sortUsing: KeyPathComparator(\.cpuPercent)) { row in
                MetricText(text: row.usage?.cpuText)
                    .help("Share of one CPU core, including worker processes; 100% is a full core.")
            }
            .width(min: 50, ideal: 70)
            .alignment(.numeric)
            .customizationID("cpu")

            TableColumn("Memory", sortUsing: KeyPathComparator(\.memoryBytes)) { row in
                MetricText(text: row.usage?.memoryText)
            }
            .width(min: 60, ideal: 80)
            .alignment(.numeric)
            .customizationID("memory")

            TableColumn("Uptime", sortUsing: KeyPathComparator(\.startedAt)) { row in
                MetricText(text: row.startedAt?.formattedUptime())
            }
            .width(min: 60, ideal: 80)
            .alignment(.numeric)
            .customizationID("uptime")

            TableColumn("PID", sortUsing: KeyPathComparator(\.pid)) { row in
                MetricText(text: row.pid.map(String.init))
            }
            .width(min: 50, ideal: 70)
            .alignment(.numeric)
            .customizationID("pid")

            TableColumn("User", sortUsing: KeyPathComparator(\.user)) { row in
                userCell(row.service)
            }
            .width(min: 60, ideal: 100)
            .customizationID("user")
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .contextMenu(forSelectionType: BrewServiceItem.ID.self) { ids in
            if let id = ids.first, let service = store.services.first(where: { $0.id == id }) {
                contextMenu(for: service)
            }
        } primaryAction: { ids in
            guard let id = ids.first else { return }
            store.selectedServiceId = id
            showsInspector = true
        }
    }

    private func userCell(_ service: BrewServiceItem) -> some View {
        HStack(spacing: Spacing.related) {
            Text(service.user ?? "\u{2014}")
                .foregroundStyle(service.user != nil ? .primary : .tertiary)
            if service.requiresRoot {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("Runs as root. Actions require your administrator password.")
                    .accessibilityLabel("Requires administrator password")
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for service: BrewServiceItem) -> some View {
        ServiceActionButtons(actions: ServiceAction.lifecycle, service: service, pending: $pendingAction)

        Divider()

        Button {
            store.selectedServiceId = service.id
            showsInspector = true
        } label: {
            Label("Show Info", systemImage: "info.circle")
        }

        if store.isHidden(service) {
            Button {
                store.unhide(service)
            } label: {
                Label("Show in List", systemImage: "eye")
            }
        } else {
            Button {
                store.hide(service)
            } label: {
                Label("Hide from List", systemImage: "eye.slash")
            }
        }

        Divider()

        ServiceActionButtons(actions: ServiceAction.destructive, service: service, pending: $pendingAction)
    }
}

// MARK: - Row

/// A table row: the service with its latest metrics, so every column sorts.
/// Nonisolated so its key paths are Sendable comparators.
nonisolated struct ServiceRow: Identifiable {
    let service: BrewServiceItem
    let usage: ResourceUsage?
    let startedAt: Date?

    var id: BrewServiceItem.ID { service.id }
    var name: String { service.name }
    var status: ServiceStatus { service.status }
    var pid: Int? { service.pid }
    var user: String? { service.user }
    var cpuPercent: Double? { usage?.cpuPercent }
    var memoryBytes: Int64? { usage?.memoryBytes }
}

// MARK: - Cells

/// A numeric cell; a dash when there is no value, such as for a stopped service.
private struct MetricText: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else {
            Text("\u{2014}")
                .foregroundStyle(.quaternary)
                .accessibilityLabel("None")
        }
    }
}

/// A count in a tinted capsule, for the toolbar.
private struct CountPill: View {
    let text: String
    let color: Color
    var isSelected = false

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(isSelected ? .white : color)
            .contentTransition(.numericText())
            .badgeInset()
            .background(isSelected ? color : color.opacity(Opacity.badgeBackground), in: Capsule())
            .transition(.scale.combined(with: .opacity))
            .padding(.horizontal, Spacing.compact)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServiceListView()
            .environment(AppStores())
    }
    .frame(width: 800, height: 500)
}
