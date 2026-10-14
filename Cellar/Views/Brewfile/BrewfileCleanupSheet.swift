import SwiftUI
import CellarCore

/// Previews `brew bundle cleanup` from its dry run and lets the user keep
/// items before anything is uninstalled.
struct BrewfileCleanupSheet: View {
    let brewfile: Brewfile

    @Environment(BrewfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Items the user unchecked; everything else is removed.
    @State private var kept: Set<String> = []

    private var items: [BrewfileContent.Entry] { store.cleanupPlan?.items ?? [] }
    private var removedCount: Int { items.count - kept.count }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            VStack(alignment: .leading, spacing: Spacing.compact) {
                Text("Clean Up Packages Not in \(brewfile.name)?")
                    .font(.headline)
                Text("Checked items will be uninstalled. Uncheck anything you want to keep. Homebrew then also removes old versions and cached downloads.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
                .frame(minHeight: WindowSize.mediumSheetHeight / 2, maxHeight: WindowSize.mediumSheetHeight)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Uninstall \(String.count(removedCount, "Item"))", role: .destructive) {
                    let keptItems = items.filter { kept.contains($0.id) }
                    Task { await store.cleanUp(brewfile, keeping: keptItems) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(store.isCheckingStatus || removedCount == 0)
            }
        }
        .padding(Spacing.section)
        .frame(width: WindowSize.mediumSheet)
        .task { await store.refreshStatus() }
    }

    @ViewBuilder
    private var content: some View {
        if store.isCheckingStatus && store.cleanupPlan == nil {
            LoadingView(message: "Checking what isn’t in the Brewfile\u{2026}")
        } else if items.isEmpty {
            EmptyStateView(
                title: "Nothing to Clean Up",
                systemImage: "checkmark.circle",
                description: "Everything installed is listed in this Brewfile."
            )
        } else {
            List {
                ForEach(BrewfileContent.Entry.Kind.allCases, id: \.self) { kind in
                    let group = items.filter { $0.kind == kind }
                    if !group.isEmpty {
                        Section {
                            ForEach(group) { item in
                                Toggle(item.name, isOn: willRemove(item))
                                    .toggleStyle(.checkbox)
                                    .disabled(item.rawLine.isEmpty)
                                    .help(item.rawLine.isEmpty ? "Cellar can’t keep this item; edit the Brewfile to keep it." : "")
                            }
                        } header: {
                            CountedSectionHeader(title: kind.title, systemImage: kind.systemImage, count: group.count)
                        }
                    }
                }
            }
            .listStyle(.bordered)
        }
    }

    private func willRemove(_ item: BrewfileContent.Entry) -> Binding<Bool> {
        Binding(
            get: { !kept.contains(item.id) },
            set: { remove in
                if remove { kept.remove(item.id) } else { kept.insert(item.id) }
            }
        )
    }
}

#Preview {
    BrewfileCleanupSheet(brewfile: Brewfile.previewList[0])
        .environment(AppStores())
}
