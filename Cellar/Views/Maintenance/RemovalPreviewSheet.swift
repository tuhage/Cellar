import SwiftUI
import CellarCore

/// Confirms a removal with what brew would actually delete, read from a dry
/// run and grouped by kind. Shared by the cleanup and autoremove previews.
struct RemovalPreviewSheet<Options: View>: View {
    let title: String
    let message: String
    let systemImage: String
    let confirmTitle: String
    let emptyTitle: String
    let emptyMessage: String
    /// Changing it runs the dry run again, such as when Deep Clean changes.
    var planID: AnyHashable = 0
    /// Confirming with nothing to remove still does something useful (Run
    /// All goes on to the health check).
    var confirmsWhenEmpty = false
    let loadPlan: () async throws -> CleanupPlan
    let confirm: () -> Void
    @ViewBuilder var options: Options

    @Environment(\.dismiss) private var dismiss
    @State private var plan: CleanupPlan?
    @State private var planError: String?
    @State private var expandedGroups: Set<CleanupPlan.Category> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.none) {
            header
                .padding(Spacing.cardPadding)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
                .padding(Spacing.cardPadding)
        }
        .frame(width: WindowSize.mediumSheet)
        .frame(minHeight: WindowSize.mediumSheetHeight, idealHeight: WindowSize.fullDetailHeight)
        .task(id: planID) { await load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let planError {
            ErrorView(message: planError) {
                Task { await load() }
            }
        } else if let plan {
            if plan.isEmpty {
                EmptyStateView(title: emptyTitle, systemImage: "checkmark.circle", description: emptyMessage)
            } else {
                List {
                    ForEach(plan.groups) { group in
                        DisclosureGroup(isExpanded: isExpanded(group.category)) {
                            ForEach(group.items) { item in
                                ItemRow(item: item)
                            }
                        } label: {
                            GroupLabel(group: group)
                        }
                    }
                }
            }
        } else {
            LoadingView(message: "Checking what can be removed\u{2026}")
        }
    }

    private func isExpanded(_ category: CleanupPlan.Category) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedGroups.insert(category)
                } else {
                    expandedGroups.remove(category)
                }
            }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            options

            if let bytes = plan?.reclaimableBytes {
                Label(
                    "Frees approximately \(bytes.formatted(.byteCount(style: .file))).",
                    systemImage: "internaldrive"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(confirmTitle, role: .destructive) {
                    confirm()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canConfirm)
            }
        }
    }

    private var canConfirm: Bool {
        guard let plan else { return false }
        return !plan.isEmpty || confirmsWhenEmpty
    }

    // MARK: - Data

    private func load() async {
        plan = nil
        planError = nil
        do {
            let plan = try await loadPlan()
            expandedGroups = plan.groups.count == 1 ? Set(plan.groups.map(\.category)) : []
            self.plan = plan
        } catch {
            guard !isOperationCancellation(error) else { return }
            planError = error.briefDescription
        }
    }
}

// MARK: - Rows

private struct GroupLabel: View {
    let group: CleanupPlan.Group

    var body: some View {
        LabeledContent {
            if group.bytes > 0 {
                Text(group.bytes.formatted(.byteCount(style: .file)))
                    .monospacedDigit()
            }
        } label: {
            Label {
                Text(group.category.title)
                Text(String.count(group.items.count, "item"))
            } icon: {
                Image(systemName: group.category.systemImage)
            }
        }
    }
}

private struct ItemRow: View {
    let item: CleanupPlan.Item

    var body: some View {
        LabeledContent {
            if let bytes = item.bytes {
                Text(bytes.formatted(.byteCount(style: .file)))
                    .monospacedDigit()
            }
        } label: {
            Text(item.title)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(item.path ?? item.title)
    }
}

// MARK: - Preview

#Preview {
    RemovalPreviewSheet(
        title: "Clean Up Homebrew",
        message: "Removes files Homebrew no longer needs.",
        systemImage: "trash.circle.fill",
        confirmTitle: "Clean Up",
        emptyTitle: "Nothing to Clean Up",
        emptyMessage: "Homebrew is tidy.",
        loadPlan: { .preview },
        confirm: {}
    ) {
        EmptyView()
    }
}
