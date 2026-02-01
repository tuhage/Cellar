import SwiftUI
import CellarCore

struct ServiceListView: View {
    @Environment(ServiceStore.self) private var store

    @State private var selectedServiceID: BrewServiceItem.ID?
    @State private var sortOrder: [KeyPathComparator<BrewServiceItem>] = [
        KeyPathComparator(\.name)
    ]

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
                    description: "No Homebrew services are installed."
                )
            } else {
                serviceTable
            }
        }
        .navigationTitle("Services")
        .toolbar {
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
                        .badgeInset()
                        .background(.green.opacity(0.1), in: Capsule())
                        .padding(.horizontal, Spacing.item)
                }
            }
        }
        .task {
            await store.load()
        }
    }

    // MARK: - Table

    private var serviceTable: some View {
        Table(store.services, selection: $selectedServiceID, sortOrder: $sortOrder) {
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
                Text(service.user ?? "--")
                    .foregroundStyle(service.user != nil ? .primary : .quaternary)
            }
            .width(min: 60, ideal: 100)
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
    }
}

// MARK: - Status Badge

private struct ServiceStatusBadge: View {
    let status: ServiceStatus

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
                    }
                }

            Text(status.label)
                .font(.callout)
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
