import SwiftUI
import UniformTypeIdentifiers
import CellarCore

// MARK: - Requests

/// Sheets the Brewfiles page presents for its rows, header and menus.
enum BrewfileSheet: Identifiable {
    case add(Brewfile.Kind)
    case edit(Brewfile, text: String)
    case cleanUp(Brewfile)
    case activate(Brewfile)
    case addPackages(Brewfile)
    case addServices(Brewfile)

    var id: String {
        switch self {
        case .add(let kind): "add-\(kind.rawValue)"
        case .edit(let brewfile, _): "edit-\(brewfile.id)"
        case .cleanUp(let brewfile): "cleanup-\(brewfile.id)"
        case .activate(let brewfile): "activate-\(brewfile.id)"
        case .addPackages(let brewfile): "packages-\(brewfile.id)"
        case .addServices(let brewfile): "services-\(brewfile.id)"
        }
    }
}

/// Actions that replace or remove something, confirmed first.
enum BrewfileConfirmation {
    case export(Brewfile)
    case trash(Brewfile)
    case remove(Brewfile)
    case removeEntry(BrewfileContent.Entry, from: Brewfile)

    var title: String {
        switch self {
        case .export(let brewfile): "Replace \(brewfile.name) with the current setup?"
        case .trash(let brewfile): "Move the Brewfile of \(brewfile.name) to the Trash?"
        case .remove(let brewfile): "Remove \(brewfile.name) from the list?"
        case .removeEntry(let entry, let brewfile): "Remove \(entry.name) from \(brewfile.name)?"
        }
    }

    var message: String {
        switch self {
        case .export(let brewfile):
            "\(brewfile.displayPath) was edited after the last export. Exporting replaces those edits; the current file is kept as \(brewfile.backupURL.lastPathComponent)."
        case .trash(let brewfile):
            "\(brewfile.displayPath) moves to the Trash, where you can restore it. Nothing is uninstalled."
        case .remove(let brewfile):
            brewfile.kind == .project
                ? "The Brewfile stays in its folder. The project’s list of services is removed from Cellar."
                : "The Brewfile stays at \(brewfile.displayPath)."
        case .removeEntry(let entry, _):
            "The line \(entry.rawLine) is deleted from the Brewfile. The package stays installed."
        }
    }

    var actionTitle: String {
        switch self {
        case .export: "Export and Replace"
        case .trash: "Move to Trash"
        case .remove: "Remove from List"
        case .removeEntry: "Remove"
        }
    }
}

// MARK: - BrewfileView

/// Brewfiles for This Mac's setup and for project folders, side by side
/// with the selected one's packages, services and actions.
struct BrewfileView: View {
    @Environment(BrewfileStore.self) private var store
    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore

    @State private var sheet: BrewfileSheet?
    @State private var confirmation: BrewfileConfirmation?
    @State private var folderToLocate: Brewfile?
    @State private var searchText = ""

    private static let listWidth: CGFloat = 250

    var body: some View {
        HStack(spacing: 0) {
            BrewfileListColumn(sheet: $sheet, confirmation: $confirmation)
                .frame(width: Self.listWidth)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { banners }
        .navigationTitle("Brewfiles")
        .dataFreshness(store.lastChecked)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter packages")
        .toolbar { toolbar }
        .sheet(item: $sheet, content: sheetContent)
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: $confirmation.isPresent(),
            titleVisibility: .visible,
            presenting: confirmation
        ) { request in
            Button(request.actionTitle, role: .destructive) { confirm(request) }
        } message: { request in
            Text(request.message)
        }
        .fileImporter(isPresented: $folderToLocate.isPresent(), allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result, let brewfile = folderToLocate {
                Task { await store.relocate(brewfile, to: url) }
            }
        }
        .task { store.loadLibraryIfNeeded() }
        .task(id: StatusKey(brewfileID: store.selectedID, packagesUpdated: packageStore.lastUpdated)) {
            await store.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await store.reloadIfChanged() }
        }
        .pageRefresh(isLoading: store.isCheckingStatus) { await store.reloadAndCheck() }
    }

    /// Re-check status when the selection changes or the package list was
    /// reloaded, such as after installing something on another page.
    private struct StatusKey: Equatable {
        let brewfileID: UUID?
        let packagesUpdated: Date?
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let brewfile = store.selected {
            BrewfileDetailView(
                brewfile: brewfile,
                searchText: searchText,
                sheet: $sheet,
                confirmation: $confirmation,
                locateFolder: { folderToLocate = brewfile }
            )
        } else {
            EmptyStateView(
                title: "No Brewfile Selected",
                systemImage: "doc.text",
                description: "Select a Brewfile, or drop a project folder on the list."
            )
        }
    }

    // MARK: - Banners

    @ViewBuilder
    private var banners: some View {
        if let message = store.errorMessage {
            NoticeBanner(tint: .red, systemImage: "exclamationmark.triangle.fill", title: message) {
                Button("Dismiss") { store.errorMessage = nil }
            }
        }
        if let brewfile = store.selected {
            if let operation = store.runningOperation(for: brewfile) {
                RunningOperationBar(operation: operation)
            }
            if !brewfile.pendingPackages.isEmpty {
                NoticeBanner(
                    tint: .orange,
                    systemImage: "shippingbox",
                    title: "\(brewfile.pendingPackages.count) packages from your project are waiting for its folder",
                    message: "\(brewfile.pendingPackages.formatted(.list(type: .and))) will be added to the Brewfile once Cellar finds \(brewfile.folderURL.lastPathComponent)."
                ) {
                    Button("Locate Folder\u{2026}") { folderToLocate = brewfile }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add Project Folder\u{2026}", systemImage: "folder.badge.plus") { sheet = .add(.project) }
                Button("Add Mac Setup Brewfile\u{2026}", systemImage: "desktopcomputer") { sheet = .add(.mac) }
            } label: {
                Label("Add Brewfile", systemImage: "plus")
            }
            .help("Add a project folder or another Brewfile")
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: BrewfileSheet) -> some View {
        switch sheet {
        case .add(let kind):
            AddBrewfileSheet(kind: kind)
        case .edit(let brewfile, let text):
            BrewfileEditorSheet(brewfile: brewfile, text: text)
        case .cleanUp(let brewfile):
            BrewfileCleanupSheet(brewfile: brewfile)
        case .activate(let brewfile):
            ActivationPreviewSheet(project: brewfile)
        case .addPackages(let brewfile):
            packagePicker(for: brewfile)
        case .addServices(let brewfile):
            servicePicker(for: brewfile)
        }
    }

    private func packagePicker(for brewfile: Brewfile) -> some View {
        let listed = Set(store.content.entries(of: .brew).map(\.name))
        let items = packageStore.formulae
            .filter { !listed.contains($0.name) && !listed.contains($0.fullName) }
            .map { ItemPickerSheet.Item(id: $0.fullName, detail: $0.desc) }
        return ItemPickerSheet(
            title: "Add Packages to \(brewfile.name)",
            items: items,
            emptyMessage: "All Installed Formulae Are Listed"
        ) { names in
            Task { await store.addPackages(names, to: brewfile) }
        }
    }

    private func servicePicker(for brewfile: Brewfile) -> some View {
        let items = serviceStore.services
            .filter { !brewfile.services.contains($0.name) }
            .map { ItemPickerSheet.Item(id: $0.name, detail: $0.status.label) }
        return ItemPickerSheet(
            title: "Add Services to \(brewfile.name)",
            items: items,
            emptyMessage: "No Other Services"
        ) { names in
            store.addServices(names, to: brewfile)
        }
    }

    // MARK: - Confirmations

    private func confirm(_ request: BrewfileConfirmation) {
        switch request {
        case .export(let brewfile):
            Task { await store.export(brewfile) }
        case .trash(let brewfile):
            store.moveToTrash(brewfile)
        case .remove(let brewfile):
            store.remove(brewfile)
        case .removeEntry(let entry, let brewfile):
            Task { await store.removeEntry(entry, from: brewfile) }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BrewfileView()
            .environment(AppStores())
    }
    .frame(width: WindowSize.fullDetailWidth + 300, height: WindowSize.fullDetailHeight)
}
