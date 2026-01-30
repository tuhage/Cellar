import SwiftUI
import CellarCore

struct ServiceDetailView: View {
    let service: BrewServiceItem

    @Environment(ServiceStore.self) private var store
    @State private var isPerformingAction = false
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                Divider()
                infoSection
                Divider()
                actionsSection
                Divider()
                logsPlaceholderSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(service.name)
        .alert("Error", isPresented: .init(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(service.name)
                .font(.largeTitle)
                .fontWeight(.bold)

            ServiceDetailStatusBadge(status: service.status)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Text("Name")
                    .foregroundStyle(.secondary)
                    .gridColumnAlignment(.trailing)
                Text(service.name)
                    .textSelection(.enabled)
                    .fontDesign(.monospaced)
            }

            GridRow {
                Text("Status")
                    .foregroundStyle(.secondary)
                Text(statusDescription)
            }

            GridRow {
                Text("PID")
                    .foregroundStyle(.secondary)
                if let pid = service.pid {
                    Text("\(pid)")
                        .textSelection(.enabled)
                        .fontDesign(.monospaced)
                } else {
                    Text("Not running")
                        .foregroundStyle(.tertiary)
                }
            }

            GridRow {
                Text("User")
                    .foregroundStyle(.secondary)
                Text(service.user ?? "None")
                    .foregroundStyle(service.user != nil ? .primary : .tertiary)
            }

            if let file = service.file {
                GridRow {
                    Text("Plist")
                        .foregroundStyle(.secondary)
                    Text(file)
                        .textSelection(.enabled)
                        .fontDesign(.monospaced)
                        .lineLimit(2)
                }
            }

            if let exitCode = service.exitCode {
                GridRow {
                    Text("Exit Code")
                        .foregroundStyle(.secondary)
                    Text("\(exitCode)")
                        .fontDesign(.monospaced)
                        .foregroundStyle(exitCode == 0 ? Color.primary : Color.red)
                }
            }

            if let registered = service.registered {
                GridRow {
                    Text("Registered")
                        .foregroundStyle(.secondary)
                    Text(registered ? "Yes" : "No")
                }
            }
        }
        .font(.body)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 12) {
                if service.isRunning {
                    Button {
                        performAction {
                            await store.stop(service)
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        performAction {
                            await store.restart(service)
                        }
                    } label: {
                        Label("Restart", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        performAction {
                            await store.start(service)
                        }
                    } label: {
                        Label("Start", systemImage: "play.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .disabled(isPerformingAction)

            if isPerformingAction {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Logs Placeholder

    private var logsPlaceholderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Logs")
                .font(.headline)

            GroupBox {
                ContentUnavailableView {
                    Label("No Logs Available", systemImage: "text.alignleft")
                } description: {
                    Text("Service log viewing will be available in a future update.")
                }
                .frame(minHeight: 150)
            }
        }
    }

    // MARK: - Helpers

    private var statusDescription: String {
        switch service.status {
        case .started: "Running"
        case .stopped: "Stopped"
        case .error: "Error"
        case .none: "None"
        case .unknown: "Unknown"
        }
    }

    private func performAction(_ action: @escaping () async -> Void) {
        isPerformingAction = true
        Task {
            await action()
            isPerformingAction = false
            if let error = store.errorMessage {
                actionError = error
            }
        }
    }
}

// MARK: - Status Badge

private struct ServiceDetailStatusBadge: View {
    let status: ServiceStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusLabel)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1), in: Capsule())
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

#Preview("Running Service") {
    NavigationStack {
        ServiceDetailView(service: BrewServiceItem.preview)
            .environment(ServiceStore())
    }
    .frame(width: 600, height: 700)
}

#Preview("Stopped Service") {
    NavigationStack {
        ServiceDetailView(
            service: BrewServiceItem(
                name: "redis",
                status: .stopped,
                user: nil,
                file: "/opt/homebrew/opt/redis/.plist",
                exitCode: 0,
                pid: nil,
                registered: true
            )
        )
        .environment(ServiceStore())
    }
    .frame(width: 600, height: 700)
}
