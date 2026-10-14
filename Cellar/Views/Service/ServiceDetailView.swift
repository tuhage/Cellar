import SwiftUI
import CellarCore

/// The Services page inspector. Give it `.id(service.name)` so per-service
/// state (loaded info, ports) doesn't carry over to the next selection.
struct ServiceDetailView: View {
    let service: BrewServiceItem
    @Binding var pendingAction: PendingServiceAction?

    @Environment(ServiceStore.self) private var store
    @Environment(ActivityStore.self) private var activityStore

    @State private var info: ServiceInfo?
    @State private var ports: [ListeningPort] = []

    private var runningOperation: BrewOperation? {
        activityStore.runningOperation(for: .package(service.name))
    }

    /// The service's latest operation, if it failed; cleared by the next attempt.
    private var lastFailure: BrewOperation? {
        activityStore.operations
            .first { $0.kind.target == .package(service.name) }
            .flatMap { $0.isFailed ? $0 : nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                headerSection
                actionsSection
                if service.isRunning {
                    ServiceUsageSection(service: service)
                }
                detailsSection
                    .padding(Spacing.cardPadding)
                    .cardStyle()
                if let info {
                    ServiceLogSection(service: service, info: info)
                }
            }
            .padding(Spacing.section)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(service.name)
        .task(id: service) {
            info = try? await service.info
        }
        .task(id: service.pid) {
            // lsof can't inspect root processes without elevating.
            guard let pid = service.pid, !service.requiresRoot else {
                ports = []
                return
            }
            ports = await ListeningPort.ports(ofProcess: pid)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: Spacing.detailElement) {
            Image(systemName: "gearshape.2")
                .font(.title2)
                .foregroundStyle(service.status.color)
                .frame(width: IconSize.headerIcon, height: IconSize.headerIcon)
                .background(service.status.color.opacity(Opacity.iconBackground), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.related) {
                Text(service.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .textSelection(.enabled)

                StatusBadge(text: service.status.label, color: service.status.color, icon: service.status.symbolName)
                    .help(service.statusHelp)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            FlowLayout(spacing: Spacing.item) {
                ServiceActionButtons(actions: ServiceAction.lifecycle, service: service, pending: $pendingAction)
                ServiceActionButtons(actions: ServiceAction.destructive, service: service, pending: $pendingAction)
            }
            .buttonStyle(.bordered)

            if service.requiresRoot {
                Label("Runs as root. Actions require your administrator password.", systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let runningOperation {
                HStack(spacing: Spacing.item) {
                    ProgressView()
                        .controlSize(.small)
                    Text("\(runningOperation.title)\u{2026}")
                        .foregroundStyle(.secondary)
                }
            } else if let lastFailure, let failure = lastFailure.failure {
                failureNotice(title: lastFailure.title, reason: failure.issue?.title ?? failure.reason)
            }
        }
    }

    private func failureNotice(title: String, reason: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            NoticeText(title: "\(title) failed", message: reason)
            Spacer()
            Button("Details") {
                ActivityPanel.show()
            }
            .controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Details

    private var detailsSection: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.cardPadding, verticalSpacing: Spacing.row) {
            detailRow("Status") {
                Text(service.status.explanation)
            }

            if let exitCode = service.exitCode, let meaning = service.exitCodeExplanation {
                detailRow("Last Exit") {
                    Text("\(meaning) (\(exitCode))")
                        .foregroundStyle(exitCode == 0 ? Color.primary : Color.red)
                }
            }

            if let pid = service.pid {
                detailRow("PID") {
                    Text(String(pid))
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
            }

            if let startedAt = store.startDate(of: service) {
                detailRow("Running For") {
                    Text(startedAt.formattedUptime(units: 2))
                        .help(startedAt.formatted(date: .abbreviated, time: .standard))
                }
            }

            if !ports.isEmpty {
                detailRow("Listening On") {
                    Text(portsDescription)
                        .textSelection(.enabled)
                }
            }

            detailRow("User") {
                Text(service.user ?? "Not registered")
                    .foregroundStyle(service.user != nil ? .primary : .tertiary)
            }

            if let registered = info?.registered ?? service.registered {
                detailRow(service.requiresRoot ? "Starts at Boot" : "Starts at Login") {
                    Text(registered ? "Yes" : "No")
                }
            }

            if let schedule {
                detailRow("Schedule") {
                    Text(schedule)
                }
            }

            if let command = info?.command {
                detailRow("Command") {
                    pathText(command)
                }
            }

            if let workingDirectory = info?.workingDirectory {
                detailRow("Working Directory") {
                    pathText(workingDirectory)
                }
            }

            if let file = service.file {
                detailRow("Plist") {
                    VStack(alignment: .leading, spacing: Spacing.compact) {
                        pathText(file)
                        FileActions(path: file)
                    }
                }
            }
        }
        .font(.body)
    }

    private func detailRow(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pathText(_ text: String) -> some View {
        Text(text)
            .font(.callout.monospaced())
            .textSelection(.enabled)
            .lineLimit(3)
    }

    /// "5432 (this Mac only), 8080".
    private var portsDescription: String {
        ports
            .map { $0.isLocalOnly ? "\($0.port) (this Mac only)" : String($0.port) }
            .formatted(.list(type: .and, width: .narrow))
    }

    private var schedule: String? {
        if let interval = info?.interval {
            let duration = Duration.seconds(interval).formatted(.units(width: .wide, maximumUnitCount: 2))
            return "Every \(duration)"
        }
        return info?.cron.map { "Cron: \($0)" }
    }
}

// MARK: - Preview

#Preview("Running Service") {
    @Previewable @State var pending: PendingServiceAction?

    ServiceDetailView(service: .preview, pendingAction: $pending)
        .environment(AppStores())
        .frame(width: 420, height: 800)
}

#Preview("Failed Root Service") {
    @Previewable @State var pending: PendingServiceAction?

    ServiceDetailView(
        service: BrewServiceItem(
            name: "dnsmasq",
            status: .error,
            user: "root",
            file: "/Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist",
            exitCode: 78,
            pid: nil,
            registered: true
        ),
        pendingAction: $pending
    )
    .environment(AppStores())
    .frame(width: 420, height: 700)
}
