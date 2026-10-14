import SwiftUI
import CellarCore

/// One Brewfile: its packages with their install status and, for a
/// project, its services; for This Mac, also what isn't in the Brewfile.
struct BrewfileDetailView: View {
    let brewfile: Brewfile
    let searchText: String
    @Binding var sheet: BrewfileSheet?
    @Binding var confirmation: BrewfileConfirmation?
    let locateFolder: () -> Void

    @Environment(BrewfileStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            BrewfileHeader(brewfile: brewfile, sheet: $sheet, confirmation: $confirmation)
            Divider()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if brewfile.kind == .project, !brewfile.folderExists {
            EmptyStateView(
                title: "Folder Not Found",
                systemImage: "questionmark.folder",
                description: "\(brewfile.folderURL.path) doesn’t exist. It may have been moved or renamed.",
                actionTitle: "Locate Folder\u{2026}",
                actionSystemImage: "folder",
                action: locateFolder
            )
        } else if brewfile.kind == .mac, !brewfile.exists {
            ContentUnavailableView {
                Label("No Brewfile Yet", systemImage: "doc.text")
            } description: {
                Text("Export what’s installed on this Mac to \(brewfile.displayPath) to back it up or set up another Mac.")
            } actions: {
                Button("Export Current Setup") { Task { await store.export(brewfile) } }
                    .buttonStyle(.borderedProminent)
                Button("Create Empty Brewfile") { store.createEmpty(brewfile) }
            }
        } else {
            List {
                if brewfile.kind == .project {
                    ProjectServicesSection(project: brewfile, sheet: $sheet)
                }
                packageSections
                if brewfile.kind == .mac {
                    notInBrewfileSection
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Packages

    private func matchesSearch(_ entry: BrewfileContent.Entry) -> Bool {
        searchText.isEmpty || entry.name.localizedCaseInsensitiveContains(searchText)
    }

    @ViewBuilder
    private var packageSections: some View {
        if !brewfile.exists {
            Section("Packages") {
                HStack {
                    Text("This folder has no Brewfile yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Create Brewfile") { store.createEmpty(brewfile) }
                }
            }
        } else if store.content.isEmpty {
            Section("Packages") {
                HStack {
                    Text("This Brewfile doesn’t list any packages yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if brewfile.kind == .project {
                        Button("Add Packages\u{2026}") { sheet = .addPackages(brewfile) }
                    }
                }
            }
        } else if !store.content.entries.contains(where: matchesSearch) {
            Section("Packages") {
                Text("No packages match “\(searchText)”.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(BrewfileContent.Entry.Kind.allCases, id: \.self) { kind in
                let entries = store.content.entries(of: kind).filter(matchesSearch)
                if !entries.isEmpty {
                    Section {
                        ForEach(entries) { entry in
                            BrewfileEntryRow(entry: entry, status: store.status(of: entry))
                                .contextMenu {
                                    Button("Remove from Brewfile\u{2026}", systemImage: "minus.circle") {
                                        confirmation = .removeEntry(entry, from: brewfile)
                                    }
                                }
                        }
                    } header: {
                        CountedSectionHeader(title: kind.title, systemImage: kind.systemImage, count: entries.count)
                    }
                }
            }
        }
    }

    // MARK: - Not in Brewfile

    @ViewBuilder
    private var notInBrewfileSection: some View {
        let items = (store.cleanupPlan?.items ?? []).filter(matchesSearch)
        Section {
            if store.cleanupPlan == nil {
                Text(store.isCheckingStatus ? "Checking what isn’t listed\u{2026}" : "Not checked yet.")
                    .foregroundStyle(.secondary)
            } else if items.isEmpty {
                Text(searchText.isEmpty ? "Everything installed is in this Brewfile." : "No matches.")
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                BrewfileEntryRow(entry: item, status: nil)
            }
        } header: {
            CountedSectionHeader(title: "Not in Brewfile", systemImage: "tray.and.arrow.up", count: items.count)
        } footer: {
            if !items.isEmpty {
                Text("Installed but not listed. Clean Up uninstalls them; Export Current Setup adds them to the Brewfile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Entry Row

private struct BrewfileEntryRow: View {
    let entry: BrewfileContent.Entry
    let status: BrewfileStore.PackageStatus?

    var body: some View {
        HStack(spacing: Spacing.item) {
            Image(systemName: entry.kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: IconSize.iconColumn)
                .accessibilityHidden(true)
            Text(entry.name)
            if entry.kind == .other {
                Text(entry.keyword)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let status {
                StatusBadge(text: status.label, color: status.color, icon: status.systemImage)
            }
        }
        .help(entry.rawLine)
    }
}

// MARK: - Preview

#Preview {
    let stores = AppStores()
    stores.brewfiles.loadLibraryIfNeeded()
    return BrewfileDetailView(
        brewfile: Brewfile.previewList[0],
        searchText: "",
        sheet: .constant(nil),
        confirmation: .constant(nil),
        locateFolder: {}
    )
    .environment(stores)
    .frame(width: 700, height: 500)
}
