import SwiftUI

struct ServiceListView: View {
    @Environment(ServiceStore.self) private var store

    @State private var selectedServiceID: BrewServiceItem.ID?
    @State private var sortOrder: [KeyPathComparator<BrewServiceItem>] = [
        KeyPathComparator(\.name)
    ]

    var body: some View {
        Group {
            if store.isLoading && store.services.isEmpty {
                LoadingView(message: "Loading services\u{2026}")
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
                Button {
                    Task { await store.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }

            ToolbarItem(placement: .status) {
                if store.runningCount > 0 {
                    Text("\(store.runningCount) running")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            if store.services.isEmpty {
                await store.load()
            }
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
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusLabel)
                .font(.callout)
        }
    }

    private var statusColor: Color {
        switch status {
        case .started: .green
        case .stopped: .secondary
        case .error: .red
        case .none: .secondary
        case .unknown: .orange
        }
    }

    private var statusLabel: String {
        switch status {
        case .started: "Running"
        case .stopped: "Stopped"
        case .error: "Error"
        case .none: "None"
        case .unknown: "Unknown"
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
