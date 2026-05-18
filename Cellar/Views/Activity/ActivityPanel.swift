import SwiftUI

/// Popover content listing every tracked Homebrew operation in the current
/// session. Reads from the shared `ActivityStore` and offers a
/// "Clear Completed" footer button.
struct ActivityPanel: View {
    @Environment(ActivityStore.self) private var store

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
                                onCancel: op.isRunning ? { store.cancel(op.id) } : nil
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
            Button("Clear Completed") {
                store.clearCompleted()
            }
            .controlSize(.small)
            .disabled(completedCount == 0)
        }
        .padding(Spacing.item)
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

#Preview("Populated") {
    let store = ActivityStore()
    _ = store.register(kind: .upgrade(name: "openssl@3", isCask: false))
    _ = store.register(kind: .upgradeAll(count: 33))
    let id3 = store.register(kind: .install(name: "wget", isCask: false))
    store.setStatus(id3, .succeeded)
    let id4 = store.register(kind: .uninstall(name: "stale-formula", isCask: false))
    store.setStatus(id4, .failed(reason: "Homebrew is busy"))
    return ActivityPanel().environment(store)
}

#Preview("Empty") {
    ActivityPanel().environment(ActivityStore())
}
