import SwiftUI
import CellarCore

/// The Brewfiles in the list: This Mac's setup files, then project folders.
/// Dropping a Brewfile or folder here adds it.
struct BrewfileListColumn: View {
    @Binding var sheet: BrewfileSheet?
    @Binding var confirmation: BrewfileConfirmation?

    @Environment(BrewfileStore.self) private var store
    @State private var isDropTargeted = false

    private var selection: Binding<UUID?> {
        Binding(get: { store.selectedID }, set: { store.select($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            list
            addBar
        }
        .dropDestination(for: URL.self) { urls, _ in
            store.addDropped(urls)
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(Spacing.compact)
                    .accessibilityHidden(true)
            }
        }
    }

    private var list: some View {
        List(selection: selection) {
            Section("This Mac") {
                ForEach(store.macBrewfiles) { row(for: $0) }
            }
            Section("Projects") {
                ForEach(store.projectBrewfiles) { row(for: $0) }
                if store.projectBrewfiles.isEmpty {
                    Text("Drop a project folder here, or click Add Project Folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .selectionDisabled()
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(for brewfile: Brewfile) -> some View {
        BrewfileRow(brewfile: brewfile)
            .tag(brewfile.id)
            .contextMenu {
                BrewfileMenuItems(brewfile: brewfile, sheet: $sheet, confirmation: $confirmation)
            }
    }

    private var addBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    sheet = .add(.project)
                } label: {
                    Label("Add Project Folder", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add a project folder and its Brewfile")
                Spacer()
            }
            .padding(Spacing.item)
        }
    }
}

// MARK: - Row

private struct BrewfileRow: View {
    let brewfile: Brewfile

    @Environment(BrewfileStore.self) private var store

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(brewfile.name)
                    .lineLimit(1)
                subtitle
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: brewfile.systemImage)
        }
        .padding(.vertical, Spacing.textPair)
    }

    @ViewBuilder
    private var subtitle: some View {
        if store.isBusy(brewfile) {
            Text("Working\u{2026}")
        } else if brewfile.kind == .mac {
            if let lastExported = brewfile.lastExported {
                Text("Exported \(lastExported, format: .relative(presentation: .named))")
            } else {
                Text(brewfile.displayPath)
            }
        } else {
            let state = store.serviceState(of: brewfile)
            if store.isActivated(brewfile), state == .running {
                StatusDotLabel(text: "Active", color: state.color)
            } else if state == .noServices {
                Text(brewfile.displayPath)
            } else {
                StatusDotLabel(text: state.label, color: state.color)
            }
        }
    }
}

// MARK: - Shared Menu

/// Actions on a Brewfile, shared by the list's context menu and the
/// detail's More menu.
struct BrewfileMenuItems: View {
    let brewfile: Brewfile
    @Binding var sheet: BrewfileSheet?
    @Binding var confirmation: BrewfileConfirmation?

    @Environment(BrewfileStore.self) private var store

    var body: some View {
        if brewfile.exists {
            Button("Edit Brewfile\u{2026}", systemImage: "pencil") {
                store.select(brewfile.id)
                sheet = .edit(brewfile, text: store.text)
            }
            Button("Open in External Editor", systemImage: "arrow.up.forward.app") {
                brewfile.openInExternalEditor()
            }
        }
        Button("Reveal in Finder", systemImage: "folder") {
            brewfile.revealInFinder()
        }

        if brewfile.kind == .project {
            Divider()
            Button("Add Packages\u{2026}", systemImage: "plus.square") {
                sheet = .addPackages(brewfile)
            }
            .disabled(!brewfile.folderExists)
            Button("Add Services\u{2026}", systemImage: "gearshape.2") {
                sheet = .addServices(brewfile)
            }
        }

        Divider()
        Button("Remove from List\u{2026}", systemImage: "minus.circle") {
            confirmation = .remove(brewfile)
        }
        .disabled(!store.canRemove(brewfile))
        if brewfile.exists {
            Button("Move Brewfile to Trash\u{2026}", systemImage: "trash", role: .destructive) {
                confirmation = .trash(brewfile)
            }
            .disabled(store.isBusy(brewfile))
        }
    }
}

#Preview {
    let stores = AppStores()
    stores.brewfiles.loadLibraryIfNeeded()
    return BrewfileListColumn(sheet: .constant(nil), confirmation: .constant(nil))
        .environment(stores)
        .frame(width: 240, height: 400)
}
