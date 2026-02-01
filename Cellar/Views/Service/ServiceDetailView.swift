import SwiftUI
import CellarCore

struct ServiceDetailView: View {
    let service: BrewServiceItem

    @Environment(ServiceStore.self) private var store
    @State private var isPerformingAction = false
    @State private var actionError: String?
    @State private var isConfirmingStop = false
    @State private var isConfirmingRestart = false

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
        .confirmationDialog(
            "Stop \(service.name)?",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                performAction {
                    await store.stop(service)
                }
            }
        } message: {
            Text("Stop \(service.name)? Running applications that depend on it may be affected.")
        }
        .confirmationDialog(
            "Restart \(service.name)?",
            isPresented: $isConfirmingRestart,
            titleVisibility: .visible
        ) {
            Button("Restart", role: .destructive) {
                performAction {
                    await store.restart(service)
                }
            }
        } message: {
            Text("Restart \(service.name)? The service will be briefly unavailable.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "gearshape.2")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(.green.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(service.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                ServiceDetailStatusBadge(status: service.status)
            }
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
                Text(service.status.label)
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
                        isConfirmingStop = true
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        isConfirmingRestart = true
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

            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)

                Text("No Logs Available")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Service log viewing will be available in a future update.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

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
                .fill(status.color)
                .frame(width: 10, height: 10)

            Text(status.label)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1), in: Capsule())
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
