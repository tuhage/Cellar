import SwiftUI
import CellarCore

/// Shows which unused dependencies `brew autoremove` would uninstall before
/// it does.
struct AutoremovePreviewSheet: View {
    @Environment(MaintenanceStore.self) private var store
    @Environment(\.refreshAll) private var refreshAll

    var body: some View {
        RemovalPreviewSheet(
            title: "Remove Unused Dependencies",
            message: "These formulae were installed only as dependencies, and nothing installed needs them anymore.",
            systemImage: "shippingbox.circle.fill",
            confirmTitle: "Uninstall",
            emptyTitle: "No Unused Dependencies",
            emptyMessage: "Every installed dependency is still needed.",
            loadPlan: { try await CleanupPlan.autoremoveDryRun() },
            confirm: confirm
        ) {
            EmptyView()
        }
    }

    /// Even a failed run may have uninstalled some, so the lists reload.
    private func confirm() {
        Task {
            await store.runAutoremove()
            await refreshAll()
        }
    }
}

#Preview {
    AutoremovePreviewSheet()
        .environment(AppStores())
}
