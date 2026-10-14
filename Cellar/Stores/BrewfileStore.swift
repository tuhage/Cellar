import Foundation
import Observation
import CellarCore

// MARK: - BrewfileCreation

/// What to put in a Brewfile that doesn't exist yet. An existing file is
/// always used as it is.
enum BrewfileCreation: String, CaseIterable, Identifiable {
    case empty
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .empty: "Empty Brewfile"
        case .export: "Export current setup"
        }
    }
}

// MARK: - BrewfileStore

/// The Brewfiles page: the saved list of Brewfiles, the selected file's
/// contents and package status, and the actions on them. Project
/// activation lives in `BrewfileStore+Activation.swift`.
///
/// Brew actions run through `ActivityStore.perform`, which reports progress
/// and failures. `errorMessage` reports what doesn't run brew — reading or
/// writing files, or checking package status.
@Observable
@MainActor
final class BrewfileStore {

    /// Whether a Brewfile entry is installed, as far as Cellar knows.
    enum PackageStatus {
        case installed, missing, outdated
    }

    // MARK: Data

    var library = BrewfileLibrary()
    var selectedID: UUID?
    /// The selected Brewfile's text and its parsed entries.
    private(set) var text = ""
    private(set) var content: BrewfileContent = .empty
    /// `nil` until `refreshStatus()` has checked the selected Brewfile.
    private(set) var check: BrewfileCheck?
    /// What cleanup would remove; only for `.mac` Brewfiles.
    private(set) var cleanupPlan: BrewfileCleanupPlan?

    // MARK: State

    private(set) var isCheckingStatus = false
    private(set) var lastChecked: Date?
    var errorMessage: String?
    private var isLibraryLoaded = false
    /// Bumped by every status check and selection change, so a slow check
    /// can't overwrite a newer result.
    private var statusGeneration = 0

    // MARK: Dependencies

    let activityStore: ActivityStore
    let packages: PackageStore
    let services: ServiceStore
    let taps: TapStore
    private let persistence = PersistenceService()
    private let brew = BrewService.shared

    init(activityStore: ActivityStore, packages: PackageStore, services: ServiceStore, taps: TapStore) {
        self.activityStore = activityStore
        self.packages = packages
        self.services = services
        self.taps = taps
    }

    // MARK: Computed

    var brewfiles: [Brewfile] { library.brewfiles }
    var macBrewfiles: [Brewfile] { brewfiles.filter { $0.kind == .mac } }
    var projectBrewfiles: [Brewfile] { brewfiles.filter { $0.kind == .project } }

    var selected: Brewfile? {
        selectedID.flatMap(brewfile(withID:))
    }

    func brewfile(withID id: UUID) -> Brewfile? {
        brewfiles.first { $0.id == id }
    }

    /// The install, export, cleanup or activation running for `brewfile`.
    func runningOperation(for brewfile: Brewfile) -> BrewOperation? {
        activityStore.runningOperation(for: .brewfile(brewfile.name))
            ?? activityStore.runningOperation(for: .project(brewfile.name))
    }

    func isBusy(_ brewfile: Brewfile) -> Bool {
        runningOperation(for: brewfile) != nil
    }

    /// `nil` while the status is unknown.
    func status(of entry: BrewfileContent.Entry) -> PackageStatus? {
        guard let check else { return nil }
        if check.isMissing(entry) { return .missing }
        let isOutdated = packages.formulae.contains { $0.outdated && entry.matches($0) }
            || packages.casks.contains { $0.outdated && entry.matches($0) }
        return isOutdated ? .outdated : .installed
    }

    var missingEntries: [BrewfileContent.Entry] {
        content.entries.filter { check?.isMissing($0) == true }
    }

    /// The last Brewfile of This Mac can't leave the list, and an active
    /// project must be deactivated first so its services aren't orphaned.
    func canRemove(_ brewfile: Brewfile) -> Bool {
        if brewfile.kind == .mac { return macBrewfiles.count > 1 }
        return library.activation?.brewfileID != brewfile.id
    }

    // MARK: - Library

    /// Loads the saved list once — migrating data from earlier versions —
    /// and makes sure This Mac is in it.
    func loadLibraryIfNeeded() {
        guard !isLibraryLoaded else { return }
        isLibraryLoaded = true
        if ProcessInfo.processInfo.isRunningForPreviews {
            library = BrewfileLibrary(brewfiles: Brewfile.previewList)
        } else {
            let loaded = BrewfileLibrary.load(using: persistence)
            library = loaded
            if macBrewfiles.isEmpty {
                library.brewfiles.insert(Brewfile(kind: .mac, name: "This Mac", path: Brewfile.defaultMacPath), at: 0)
            }
            // Saving only what changed keeps an unreadable list file intact.
            if library != loaded || !persistence.exists(fileName: BrewfileLibrary.fileName) {
                save()
            }
            writePendingPackages()
        }
        if selectedID == nil {
            select(brewfiles.first?.id)
        }
    }

    func select(_ id: UUID?) {
        guard id != selectedID else { return }
        selectedID = id
        statusGeneration += 1
        isCheckingStatus = false
        check = nil
        cleanupPlan = nil
        lastChecked = nil
        reloadContent()
    }

    /// Adds a Brewfile to the list and selects it. An existing file is
    /// adopted unchanged; otherwise one is created as `creation` says, or
    /// not at all.
    func add(kind: Brewfile.Kind, name: String, path: String, creation: BrewfileCreation? = nil) {
        if let existing = brewfiles.first(where: { $0.path == path }) {
            select(existing.id)
            return
        }
        let brewfile = Brewfile(kind: kind, name: name, path: path)
        library.brewfiles.append(brewfile)
        save()
        select(brewfile.id)
        guard !brewfile.exists, let creation else { return }
        switch creation {
        case .empty: createEmpty(brewfile)
        case .export: Task { await export(brewfile) }
        }
    }

    /// Adds dropped Brewfiles and folders: a folder or a file named
    /// `Brewfile` is a project, any other file a Mac setup. Nothing is
    /// created on disk. Returns whether anything could be added.
    @discardableResult
    func addDropped(_ urls: [URL]) -> Bool {
        let fileURLs = urls.filter(\.isFileURL)
        for url in fileURLs {
            let path = Brewfile.path(forFileOrFolder: url)
            let isProject = Brewfile.isNamedBrewfile(path) && !Brewfile.isDefaultMacPath(path)
            add(kind: isProject ? .project : .mac, name: Brewfile.suggestedName(forPath: path), path: path)
        }
        return !fileURLs.isEmpty
    }

    /// Shows the Brewfile at `path` — from Finder's "Open in Cellar" —
    /// adding its folder as a project when it isn't listed yet. Links never
    /// create files, so a missing Brewfile is ignored.
    func open(path: String) {
        loadLibraryIfNeeded()
        let path = Brewfile.path(forFileOrFolder: URL(fileURLWithPath: path))
        guard FileManager.default.fileExists(atPath: path) else { return }
        addDropped([URL(fileURLWithPath: path)])
    }

    /// Removes the Brewfile from the list; the file stays where it is.
    func remove(_ brewfile: Brewfile) {
        guard canRemove(brewfile) else { return }
        library.brewfiles.removeAll { $0.id == brewfile.id }
        save()
        if selectedID == brewfile.id {
            select(brewfiles.first?.id)
        }
    }

    /// Points a project at another folder, such as after it moved.
    func relocate(_ brewfile: Brewfile, to folder: URL) async {
        update(brewfile) { $0.path = Brewfile.path(forFileOrFolder: folder) }
        writePendingPackages()
        await reloadAndCheck()
    }

    func addServices(_ names: [String], to brewfile: Brewfile) {
        update(brewfile) { project in
            project.services += names.filter { !project.services.contains($0) }
        }
    }

    func removeService(_ name: String, from brewfile: Brewfile) {
        update(brewfile) { $0.services.removeAll { $0 == name } }
    }

    func update(_ brewfile: Brewfile, _ change: (inout Brewfile) -> Void) {
        guard let index = brewfiles.firstIndex(where: { $0.id == brewfile.id }) else { return }
        change(&library.brewfiles[index])
        save()
    }

    func save() {
        do {
            try persistence.save(library, to: BrewfileLibrary.fileName)
        } catch {
            errorMessage = "Your Brewfile list couldn’t be saved: \(error.localizedDescription)"
        }
    }

    /// Writes packages carried over from the old Projects page into their
    /// project's Brewfile once its folder exists.
    private func writePendingPackages() {
        for brewfile in brewfiles where !brewfile.pendingPackages.isEmpty && brewfile.folderExists {
            attempt("Packages couldn’t be added to \(brewfile.displayPath)") {
                try brewfile.addFormulae(brewfile.pendingPackages)
                update(brewfile) { $0.pendingPackages = [] }
            }
        }
    }

    // MARK: - File

    /// Re-reads the selected Brewfile, such as after it was edited elsewhere.
    func reloadContent() {
        guard let brewfile = selected, brewfile.exists else {
            text = ""
            content = .empty
            return
        }
        attempt("\(brewfile.displayPath) couldn’t be read") {
            text = try brewfile.read()
            content = BrewfileContent.parse(from: text)
        }
    }

    func save(_ newText: String, to brewfile: Brewfile) async {
        attempt("\(brewfile.displayPath) couldn’t be saved") {
            try brewfile.write(newText)
        }
        await reloadAndCheck()
    }

    func createEmpty(_ brewfile: Brewfile) {
        attempt("\(brewfile.displayPath) couldn’t be created") {
            try brewfile.createIfMissing()
        }
        reloadContent()
    }

    func addPackages(_ names: [String], to brewfile: Brewfile) async {
        attempt("Packages couldn’t be added to \(brewfile.displayPath)") {
            try brewfile.addFormulae(names)
        }
        await reloadAndCheck()
    }

    func removeEntry(_ entry: BrewfileContent.Entry, from brewfile: Brewfile) async {
        attempt("\(entry.name) couldn’t be removed from \(brewfile.displayPath)") {
            try brewfile.write(BrewfileContent.removing(entry, from: brewfile.read()))
        }
        await reloadAndCheck()
    }

    /// Moves the file to the Trash; the list keeps the entry so the
    /// Brewfile can be created again.
    func moveToTrash(_ brewfile: Brewfile) {
        attempt("\(brewfile.displayPath) couldn’t be moved to the Trash") {
            try brewfile.moveToTrash()
        }
        reloadContent()
    }

    /// Runs file work and reports a failure as `errorMessage`.
    private func attempt(_ failureMessage: String, _ work: () throws -> Void) {
        do {
            try work()
        } catch {
            errorMessage = "\(failureMessage). \(error.localizedDescription)"
        }
    }

    // MARK: - Status

    /// Re-reads the file, then asks brew what's missing and — for a Mac
    /// setup — what cleanup would remove.
    func reloadAndCheck() async {
        reloadContent()
        await refreshStatus()
    }

    /// Picks up edits made in another app, re-checking only if the text changed.
    func reloadIfChanged() async {
        let previous = text
        reloadContent()
        if text != previous {
            await refreshStatus()
        }
    }

    func refreshStatus() async {
        guard let brewfile = selected, brewfile.exists else { return }
        statusGeneration += 1
        let generation = statusGeneration
        isCheckingStatus = true
        defer { if generation == statusGeneration { isCheckingStatus = false } }
        do {
            async let check = brew.bundleCheck(at: brewfile.path)
            async let plan = brewfile.kind == .mac ? brew.bundleCleanupPlan(at: brewfile.path) : nil
            let (newCheck, newPlan) = try await (check, plan)
            guard generation == statusGeneration else { return }
            self.check = newCheck
            cleanupPlan = newPlan
            lastChecked = Date()
        } catch where generation == statusGeneration && !isOperationCancellation(error) {
            errorMessage = "Package status couldn’t be checked: \(error.briefDescription)"
        } catch {}
    }

    // MARK: - Brew Actions

    /// Installs what the Brewfile lists but isn't installed.
    func installMissing(from brewfile: Brewfile) async {
        await perform(.brewfileInstall(name: brewfile.name), changesPackages: true) { activity in
            try await activity.stream(self.brew.bundleInstallMissing(from: brewfile.path))
        }
    }

    /// Replaces the Brewfile with what is installed now, keeping the
    /// previous version as `Brewfile.bak`.
    func export(_ brewfile: Brewfile) async {
        await perform(.brewfileExport(name: brewfile.name), changesPackages: false) { activity in
            if brewfile.exists {
                try brewfile.backUp()
                activity.log("Saved the previous version as \(brewfile.backupURL.lastPathComponent)")
            }
            try await self.brew.bundleDump(to: brewfile.path)
            self.update(brewfile) { $0.lastExported = brewfile.modificationDate ?? Date() }
        }
    }

    /// Uninstalls what the Brewfile doesn't list, except `kept`, which
    /// stays installed through a temporary copy of the Brewfile that also
    /// lists it. The user's file isn't changed.
    func cleanUp(_ brewfile: Brewfile, keeping kept: [BrewfileContent.Entry]) async {
        await perform(.brewfileCleanup(name: brewfile.name), changesPackages: true) { activity in
            guard !kept.isEmpty else {
                try await activity.stream(self.brew.bundleCleanup(at: brewfile.path))
                return
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Cellar-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let copy = Brewfile(kind: .mac, name: brewfile.name, path: Brewfile.path(inFolder: folder))
            try copy.write(BrewfileCleanupPlan.brewfileText(brewfile.read(), keeping: kept))
            activity.log("Keeping \(kept.map(\.name).formatted(.list(type: .and)))")
            try await activity.stream(self.brew.bundleCleanup(at: copy.path))
        }
    }

    /// Runs a Brewfile action as an activity, then refreshes what it
    /// changed; see `ActivityStore.perform(_:retry:reloading:_:)`.
    private func perform(
        _ kind: BrewOperation.Kind,
        changesPackages: Bool,
        _ body: @escaping @MainActor (ActivityContext) async throws -> Void
    ) async {
        await activityStore.perform(kind, reloading: {
            await (changesPackages ? self.reloadPackages() : self.reloadAndCheck())
        }, body)
    }

    /// The Brewfiles page re-checks status when the package list reloads.
    private func reloadPackages() async {
        reloadContent()
        async let packages: Void = packages.loadAll(forceRefresh: true)
        async let taps: Void = taps.load(forceRefresh: true)
        _ = await (packages, taps)
    }
}
