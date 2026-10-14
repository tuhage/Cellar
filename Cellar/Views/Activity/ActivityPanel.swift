import SwiftUI

/// Every Homebrew operation of the session, grouped by what needs
/// attention. Shown in the toolbar popover and the Activity window.
struct ActivityPanel: View {
    @Environment(ActivityStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            if store.operations.isEmpty {
                EmptyStateView(
                    title: "No Activity",
                    systemImage: "clock.arrow.circlepath",
                    description: "Installs, upgrades and other Homebrew operations appear here."
                )
            } else {
                List {
                    section("Running", operations: running)
                    section("Needs Attention", operations: failed)
                    section("Done", operations: done)
                }
                .listStyle(.plain)
            }
            Divider()
            footer
        }
    }

    // MARK: - Sections

    private var running: [BrewOperation] { store.operations.filter(\.isRunning) }
    private var failed: [BrewOperation] { store.operations.filter(\.isFailed) }
    private var done: [BrewOperation] { store.operations.filter { !$0.isRunning && !$0.isFailed } }

    @ViewBuilder
    private func section(_ title: String, operations: [BrewOperation]) -> some View {
        if !operations.isEmpty {
            Section {
                ForEach(operations) { operation in
                    ActivityRow(operation: operation)
                }
            } header: {
                Text("\(title) · \(operations.count)")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.item) {
            Button("Logs", systemImage: "folder") {
                openLogsFolder()
            }
            .help("Show saved operation logs in Finder")

            Spacer()

            Button("Clear Completed") {
                store.clearCompleted()
            }
            .disabled(done.isEmpty)
            .help("Remove finished operations; failures stay until removed")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(Spacing.item)
    }

    private func openLogsFolder() {
        let directory = ActivityLogService.shared.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }
}

#Preview("Populated") {
    ActivityPanel()
        .frame(width: 380, height: 480)
        .environment(AppStores(activity: .preview(BrewOperation.previewList)))
}

#Preview("Empty") {
    ActivityPanel()
        .frame(width: 380, height: 300)
        .environment(AppStores())
}
