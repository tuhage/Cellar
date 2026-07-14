import SwiftUI
import CellarCore

struct ServiceListView: View {
    @Environment(ServiceStore.self) private var store

    @State private var sortOrder: [KeyPathComparator<BrewServiceItem>] = [
        KeyPathComparator(\.name)
    ]
    @State private var serviceToKill: BrewServiceItem?
    @State private var serviceToUninstall: BrewServiceItem?

    private var selectedServiceID: Binding<BrewServiceItem.ID?> {
        Binding(
            get: { store.selectedServiceId },
            set: { store.selectedServiceId = $0 }
        )
    }

    private var selectedService: BrewServiceItem? {
        guard let id = store.selectedServiceId else { return nil }
        return store.services.first { $0.id == id }
    }

    private var isInspectorPresented: Binding<Bool> {
        Binding(
            get: { selectedService != nil },
            set: { if !$0 { store.selectedServiceId = nil } }
        )
    }

    var body: some View {
        Group {
            if store.isLoading && store.services.isEmpty {
                LoadingView(message: "Loading Services\u{2026}")
            } else if let errorMessage = store.errorMessage, store.services.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await store.load() }
                }
            } else if store.services.isEmpty {
                EmptyStateView(
                    title: "No Services",
                    systemImage: "gearshape.2",
                    description: "Homebrew services will appear here."
                )
            } else {
                serviceTable
            }
        }
        .navigationTitle("Services")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        store.showsUnusedServices.toggle()
                    } label: {
                        Label(
                            "Show Unused Services",
                            systemImage: store.showsUnusedServices ? "checkmark" : ""
                        )
                    }

                    Button {
                        store.showsHiddenServices.toggle()
                    } label: {
                        Label(
                            "Show Hidden Services",
                            systemImage: store.showsHiddenServices ? "checkmark" : ""
                        )
                    }
                    .disabled(store.hiddenCount == 0)

                    if store.hiddenCount > 0 {
                        Divider()
                        Button("Unhide All (\(store.hiddenCount))") {
                            store.unhideAll()
                        }
                    }
                } label: {
                    Image(
                        systemName: hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
                .help("Filter services")
            }

            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(isLoading: store.isLoading) {
                    await store.load(forceRefresh: true)
                }
            }

            ToolbarItem(placement: .status) {
                if store.runningCount > 0 {
                    Text("\(store.runningCount) running")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                        .badgeInset()
                        .background(.green.opacity(Opacity.badgeBackground), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .padding(.horizontal, Spacing.item)
                }
            }
        }
        .task {
            await store.load()
        }
        .inspector(isPresented: isInspectorPresented) {
            if let selectedService {
                ServiceDetailView(service: selectedService)
                    .inspectorColumnWidth(min: 360, ideal: 420, max: 540)
            }
        }
    }

    // MARK: - Table

    private var hasActiveFilters: Bool {
        !store.showsUnusedServices || (store.hiddenCount > 0 && !store.showsHiddenServices)
    }

    private var serviceTable: some View {
        Table(store.visibleServices, selection: selectedServiceID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { service in
                Text(service.name)
                    .fontWeight(.medium)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Status") { service in
                ServiceStatusBadge(status: service.status)
            }
            .width(min: 80, ideal: 100)

            TableColumn("PID") { service in
                if let pid = service.pid {
                    Text("\(pid)")
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .foregroundStyle(.quaternary)
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("User") { service in
                HStack(spacing: Spacing.related) {
                    Text(service.user ?? "--")
                        .foregroundStyle(service.user != nil ? .primary : .quaternary)
                    if service.requiresRoot {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("Runs as root — actions require your administrator password.")
                    }
                }
            }
            .width(min: 60, ideal: 100)

            TableColumn("") { service in
                Menu {
                    serviceContextMenu(for: service)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }
            .width(28)
        }
        .contextMenu(forSelectionType: BrewServiceItem.ID.self) { selectedIDs in
            if let id = selectedIDs.first,
               let service = store.services.first(where: { $0.id == id }) {
                serviceContextMenu(for: service)
            }
        } primaryAction: { _ in }
        .onChange(of: sortOrder) { _, newOrder in
            store.services.sort(using: newOrder)
        }
        .animation(AnimationToken.smooth, value: store.visibleServices)
        .confirmationDialog(
            "Force stop \(serviceToKill?.name ?? "this service")?",
            isPresented: Binding(
                get: { serviceToKill != nil },
                set: { if !$0 { serviceToKill = nil } }
            ),
            presenting: serviceToKill
        ) { service in
            Button("Force Stop", role: .destructive) {
                Task { await store.kill(service) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { service in
            Text("Force stop \(service.name)? This immediately kills the process (SIGKILL) — the service may not clean up properly.")
        }
        .confirmationDialog(
            "Uninstall \(serviceToUninstall?.name ?? "this formula")?",
            isPresented: Binding(
                get: { serviceToUninstall != nil },
                set: { if !$0 { serviceToUninstall = nil } }
            ),
            presenting: serviceToUninstall
        ) { service in
            Button("Uninstall", role: .destructive) {
                Task { await store.uninstall(service) }
            }
            Button("Force Uninstall (ignore dependencies)", role: .destructive) {
                Task { await store.uninstall(service, force: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { service in
            Text("Uninstall \(service.name)? This stops the service and removes the formula from Homebrew.")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func serviceContextMenu(for service: BrewServiceItem) -> some View {
        if service.isRunning {
            Button {
                Task { await store.stop(service) }
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }

            Button {
                serviceToKill = service
            } label: {
                Label("Force Stop", systemImage: "bolt.slash.circle")
            }

            Button {
                Task { await store.restart(service) }
            } label: {
                Label("Restart", systemImage: "arrow.clockwise.circle")
            }
        } else {
            Button {
                Task { await store.start(service) }
            } label: {
                Label("Start", systemImage: "play.circle")
            }
        }

        Divider()

        Button(role: .destructive) {
            serviceToUninstall = service
        } label: {
            Label("Uninstall", systemImage: "trash")
        }

        Divider()

        if store.hiddenServiceNames.contains(service.name) {
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
    }
}

// MARK: - Status Badge

private struct ServiceStatusBadge: View {
    let status: ServiceStatus

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: Spacing.related) {
            Circle()
                .fill(status.color)
                .frame(width: IconSize.statusDot, height: IconSize.statusDot)
                .overlay {
                    if status == .started {
                        Circle()
                            .fill(status.color.opacity(0.4))
                            .frame(width: IconSize.dotGlow, height: IconSize.dotGlow)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                            .opacity(isPulsing ? 0.0 : 0.4)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                    }
                }

            Text(status.label)
                .font(.callout)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.label)")
        .help("Status: \(status.label)")
        .onAppear {
            if status == .started { isPulsing = true }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServiceListView()
            .environment(ServiceStore())
    }
    .frame(width: 700, height: 500)
}
