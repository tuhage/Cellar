import SwiftUI

/// Confirms `brew cleanup` before it deletes anything.
struct CleanupPreviewSheet: View {
    @Environment(MaintenanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            Text("Clean Up Homebrew?")
                .font(.headline)
            Text("Removes old package versions and cached downloads.")
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Clean Up") {
                    Task { await store.runCleanup() }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.section)
        .frame(width: WindowSize.narrowSheet)
    }
}

#Preview {
    CleanupPreviewSheet()
        .environment(AppStores())
}
