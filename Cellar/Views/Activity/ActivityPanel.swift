import SwiftUI
import CellarCore

/// Popover content listing every tracked Homebrew operation in the current
/// session. Reads from the shared `ActivityStore` and offers a
/// "Clear Completed" footer button.
struct ActivityPanel: View {
    @Environment(ActivityStore.self) private var store
    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore

    var body: some View {
        VStack(spacing: 0) {
            if store.operations.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(store.operations) { op in
                            ActivityRow(
                                operation: op,
                                onCancel: op.isRunning && store.canCancel(op.id)
                                    ? { store.cancel(op.id) }
                                    : nil,
                                onForceRetry: shouldOfferForceRetry(op) ? { forceRetry(op) } : nil,
                                onRetry: store.canRetry(op.id) ? { retry(op) } : nil
                            )
                            .padding(.horizontal, Spacing.cardPadding)
                            Divider()
                        }
                    }
                }
                Divider()
                footer
            }
        }
        .frame(width: 360)
        .frame(minHeight: 140, maxHeight: 480)
    }

    private func retry(_ operation: BrewOperation) {
        Task { await store.retry(operation.id) }
    }

    // MARK: - Force Retry

    private func shouldOfferForceRetry(_ op: BrewOperation) -> Bool {
        guard case .failed(let reason) = op.status else { return false }
        guard case .uninstall = op.kind else { return false }
        return reason.contains("--ignore-dependencies") || reason.contains("Refusing to uninstall")
    }

    private func forceRetry(_ op: BrewOperation) {
        guard case .uninstall(let name, let isCask) = op.kind else { return }
        Task {
            if isCask {
                if let cask = packageStore.casks.first(where: { $0.token == name }) {
                    await packageStore.uninstall(cask, force: true)
                    return
                }
            } else {
                if let formula = packageStore.formulae.first(where: { $0.name == name }) {
                    await packageStore.uninstall(formula, force: true)
                    return
                }
                if let svc = serviceStore.services.first(where: { $0.name == name }) {
                    await serviceStore.uninstall(svc, force: true)
                    return
                }
            }
            // Fallback: stores not yet loaded — call brew directly
            await directForceUninstall(name: name, isCask: isCask)
        }
    }

    private func directForceUninstall(name: String, isCask: Bool) async {
        await store.perform(.uninstall(name: name, isCask: isCask)) { _ in
            try await BrewService.shared.uninstall(name, force: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.item) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No activity")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Long-running Homebrew operations will appear here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.section)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(footerSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                openLogsFolder()
            } label: {
                Label("Logs", systemImage: "folder")
            }
            .controlSize(.small)
            .help("Show saved operation logs in Finder")
            ClearCompletedButton(isDisabled: completedCount == 0) {
                store.clearCompleted()
            }
        }
        .padding(Spacing.item)
    }

    private func openLogsFolder() {
        let directory = ActivityLogService.shared.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private var completedCount: Int {
        store.operations.filter { !$0.isRunning }.count
    }

    private var footerSummary: String {
        let running = store.runningCount
        let completed = completedCount
        if running > 0 && completed > 0 {
            return "\(running) running, \(completed) completed"
        } else if running > 0 {
            return "\(running) running"
        } else if completed > 0 {
            return "\(completed) completed"
        } else {
            return ""
        }
    }
}

// MARK: - Clear Completed Button

private struct ClearCompletedButton: View {
    var isDisabled: Bool
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button("Clear Completed", action: action)
            .controlSize(.small)
            .disabled(isDisabled)
            .foregroundStyle(isHovered && !isDisabled ? .primary : .secondary)
            .animation(AnimationToken.interactive, value: isHovered)
            .onHover { isHovered = $0 }
            .help("Remove completed and failed entries from the list")
    }
}

#Preview("Populated") {
    ActivityPanel()
        .environment(AppStores(activity: .preview(BrewOperation.previewList)))
}

#Preview("Empty") {
    ActivityPanel()
        .environment(AppStores())
}
