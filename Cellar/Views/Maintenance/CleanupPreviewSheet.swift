import SwiftUI
import CellarCore

/// Shows what `brew cleanup` would remove before it deletes anything. Every
/// user-started cleanup goes through it (`isCleanupPreviewPresented`).
struct CleanupPreviewSheet: View {
    @Environment(MaintenanceStore.self) private var store
    @Environment(\.refreshAll) private var refreshAll

    @State private var depth: CleanupDepth = .standard

    var body: some View {
        RemovalPreviewSheet(
            title: store.checksHealthAfterCleanup ? "Clean Up and Check Health" : "Clean Up Homebrew",
            message: "Removes files Homebrew no longer needs. Installed packages keep working.",
            systemImage: "trash.circle.fill",
            confirmTitle: "Clean Up",
            emptyTitle: "Nothing to Clean Up",
            emptyMessage: "There are no old versions, outdated downloads or logs to remove.",
            planID: depth,
            confirmsWhenEmpty: store.checksHealthAfterCleanup,
            loadPlan: { try await CleanupPlan.cleanupDryRun(depth) },
            confirm: confirm
        ) {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Toggle("Deep Clean", isOn: isDeepClean)
                Text("Also removes every cached download, including those of installed versions. Reinstalling a package downloads it again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var isDeepClean: Binding<Bool> {
        Binding(
            get: { depth == .deep },
            set: { depth = $0 ? .deep : .standard }
        )
    }

    /// Cleanup also uninstalls unused dependencies, so the package lists are
    /// reloaded afterwards.
    private func confirm() {
        let checksHealth = store.checksHealthAfterCleanup
        let depth = depth
        Task {
            if checksHealth {
                await store.runAll(depth: depth)
            } else {
                await store.runCleanup(depth: depth)
            }
            await refreshAll()
        }
    }
}

#Preview {
    CleanupPreviewSheet()
        .environment(AppStores())
}
