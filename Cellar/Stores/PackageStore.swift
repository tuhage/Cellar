import Foundation
import Observation
import CellarCore

// MARK: - PackageStore

/// Installed formulae and casks, plus the actions that change them.
///
/// Actions run through `ActivityStore.perform`, which reports progress and
/// failures; this store only reloads the lists afterwards.
@Observable
@MainActor
final class PackageStore: LoadableStore {

    // MARK: Data

    var formulae: [Formula] = []
    var casks: [Cask] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    /// Set to show the Upgrade All preview from anywhere in the app.
    var isUpgradePreviewPresented = false

    /// Selection and Homebrew search of the Formulae page.
    let formulaList = PackageListState()
    /// Selection and Homebrew search of the Casks page.
    let caskList = PackageListState()

    // MARK: Dependencies

    let activityStore: ActivityStore
    private static let cache = CachePolicy(fileName: "cache-packages.json")

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
    }

    // MARK: Lists

    func list(_ kind: PackageKind) -> PackageListState {
        switch kind {
        case .formula: formulaList
        case .cask: caskList
        }
    }

    /// Installed packages of one kind, in brew's order.
    func packages(_ kind: PackageKind) -> [PackageType] {
        switch kind {
        case .formula: formulae.map(PackageType.formula)
        case .cask: casks.map(PackageType.cask)
        }
    }

    /// The installed package with this ID, if any.
    func package(_ id: PackageID) -> PackageType? {
        switch id.kind {
        case .formula: formulae.first { $0.name == id.name }.map(PackageType.formula)
        case .cask: casks.first { $0.token == id.name }.map(PackageType.cask)
        }
    }

    /// The installed package with this ID, or else the search result of
    /// its page with it.
    func packageOrSearchResult(_ id: PackageID) -> PackageType? {
        package(id) ?? list(id.kind).searchResults.first { $0.id == id }
    }

    /// Whether an operation — including a queued batch step — keeps the
    /// package busy. Use it to disable actions.
    func isBusy(_ package: PackageType) -> Bool {
        activityStore.isActive(.package(package.activityName))
    }

    // MARK: Outdated

    var outdatedFormulae: [Formula] {
        formulae.filter(\.outdated)
    }

    var outdatedCasks: [Cask] {
        casks.filter(\.outdated)
    }

    /// Outdated formulae, then outdated casks.
    var outdatedPackages: [PackageType] {
        outdatedFormulae.map(PackageType.formula) + outdatedCasks.map(PackageType.cask)
    }

    var totalOutdated: Int {
        outdatedFormulae.count + outdatedCasks.count
    }

    /// Whether Upgrade All has something to do and no Homebrew-wide
    /// operation (another upgrade, `brew update`, cleanup) is in the way.
    var canUpgradeAll: Bool {
        outdatedPackages.contains(where: \.canUpgrade) && !activityStore.isActive(.homebrew)
    }

    var pinnedOutdatedFormulae: [Formula] {
        outdatedFormulae.filter(\.pinned)
    }

    var pinnedOutdatedCount: Int {
        pinnedOutdatedFormulae.count
    }

    /// Installed formulae that need `formula` at runtime.
    func dependents(of formula: Formula) -> [Formula] {
        formula.dependents(in: formulae)
    }

    // MARK: Loading

    func load(forceRefresh: Bool = false) async {
        await load(
            cache: Self.cache,
            force: forceRefresh,
            failureMessage: "Homebrew packages couldn’t be loaded."
        ) {
            async let formulae = Formula.all
            async let casks = Cask.all
            let lists = try await PackageLists(formulae: formulae, casks: casks)
            await SpotlightService.shared.indexAll(formulae: lists.formulae, casks: lists.casks)
            return lists
        } apply: { lists in
            self.formulae = lists.formulae
            self.casks = lists.casks
        }
    }

    // MARK: Install

    func install(_ package: PackageType) async {
        switch package {
        case .formula(let formula): await installFormula(name: formula.fullName)
        case .cask(let cask): await installCask(cask)
        }
    }

    /// Installs and then selects the formula so its inspector — with any
    /// caveats — opens.
    func installFormula(name: String) async {
        let installedName = PackageType.formula(.stub(name: name)).activityName
        let succeeded = await perform(.install(name: installedName, isCask: false)) { activity in
            try await activity.stream(Formula.installOutput(name: name))
        }
        if succeeded {
            formulaList.select(PackageID(kind: .formula, name: installedName))
        }
    }

    /// Installs and then selects the cask so its inspector opens.
    func installCask(_ cask: Cask) async {
        let succeeded = await perform(.install(name: cask.token, isCask: true)) { activity in
            try await activity.stream(cask.installOutput())
        }
        if succeeded {
            caskList.select(PackageID(kind: .cask, name: cask.token))
        }
    }

    // MARK: Upgrade

    func upgrade(_ package: PackageType) async {
        switch package {
        case .formula(let formula): await upgrade(formula)
        case .cask(let cask): await upgrade(cask)
        }
    }

    func upgrade(_ formula: Formula) async {
        await perform(.upgrade(name: formula.name, isCask: false)) { activity in
            try await activity.stream(formula.upgradeOutput())
        }
    }

    func upgrade(_ cask: Cask) async {
        await perform(.upgrade(name: cask.token, isCask: true)) { activity in
            try await activity.stream(cask.upgradeOutput())
        }
    }

    /// Upgrades a cask that updates itself, which brew otherwise skips.
    func forceUpgrade(_ cask: Cask) async {
        await perform(.upgrade(name: cask.token, isCask: true)) { activity in
            try await activity.stream(cask.greedyUpgradeOutput())
        }
    }

    /// brew refuses to upgrade a pinned formula, so unpin it first.
    func unpinAndUpgrade(_ formula: Formula) async {
        guard await unpin(formula) else { return }
        await upgrade(formula)
    }

    /// Upgrades several packages as one batch with per-package progress;
    /// a single package upgrades on its own. Pinned formulae are skipped.
    func upgrade(_ packages: [PackageType]) async {
        let upgradable = packages.filter(\.canUpgrade)
        if upgradable.count == 1, let package = upgradable.first {
            await upgrade(package)
            return
        }
        startUpgradeBatch(upgradable)
    }

    func reinstall(_ package: PackageType) async {
        await perform(.reinstall(name: package.identifier, isCask: package.kind == .cask)) { activity in
            switch package {
            case .formula(let formula): try await activity.stream(formula.reinstallOutput())
            case .cask(let cask): try await activity.stream(cask.reinstallOutput())
            }
        }
    }

    // MARK: Uninstall

    func uninstall(_ formula: Formula, force: Bool = false) async {
        let succeeded = await perform(.uninstall(name: formula.name, isCask: false)) { _ in
            try await formula.uninstall(force: force)
        }
        if succeeded {
            formulaList.deselect(PackageID(kind: .formula, name: formula.name))
        }
    }

    /// - Parameters:
    ///   - force: Remove it even if brew thinks it isn't installed.
    ///   - zap: Also delete the app's settings, caches and support files.
    func uninstall(_ cask: Cask, force: Bool = false, zap: Bool = false) async {
        let succeeded = await perform(.uninstall(name: cask.token, isCask: true)) { _ in
            try await cask.uninstall(force: force, zap: zap)
        }
        if succeeded {
            caskList.deselect(PackageID(kind: .cask, name: cask.token))
        }
    }

    /// Uninstalls one package after another.
    /// - Parameters:
    ///   - ignoringDependents: Remove formulae other formulae still need.
    ///   - zap: Also delete cask app data.
    func uninstall(_ packages: [PackageType], ignoringDependents: Bool = false, zap: Bool = false) async {
        for package in packages {
            switch package {
            case .formula(let formula): await uninstall(formula, force: ignoringDependents)
            case .cask(let cask): await uninstall(cask, zap: zap)
            }
        }
    }

    // MARK: Pin

    @discardableResult
    func pin(_ formula: Formula) async -> Bool {
        await perform(.pin(name: formula.name)) { _ in try await formula.pin() }
    }

    @discardableResult
    func unpin(_ formula: Formula) async -> Bool {
        await perform(.unpin(name: formula.name)) { _ in try await formula.unpin() }
    }

    /// Pins or unpins each formula that isn't already in that state.
    func setPinned(_ pinned: Bool, for formulae: [Formula]) async {
        for formula in formulae where formula.pinned != pinned {
            if pinned {
                await pin(formula)
            } else {
                await unpin(formula)
            }
        }
    }

    // MARK: Update Check

    /// When Cellar last ran `brew update`.
    private(set) var lastUpdateCheck = UserDefaults.standard.object(forKey: SettingsKey.lastHomebrewUpdateCheck) as? Date

    /// Matches brew's own auto-update interval.
    private static let automaticCheckInterval: TimeInterval = 86_400

    var isCheckingForUpdates: Bool {
        activityStore.runningOperation(for: .homebrew)?.kind == .brewUpdate
    }

    /// Runs `brew update` so outdated packages reflect what is actually
    /// available — every other brew call runs with auto-update off — then
    /// reloads the package lists.
    func checkForUpdates(background: Bool = false) async {
        await activityStore.perform(.brewUpdate, background: background) { activity in
            try await activity.stream(BrewService.shared.update())
            let checkedAt = Date()
            self.lastUpdateCheck = checkedAt
            UserDefaults.standard.set(checkedAt, forKey: SettingsKey.lastHomebrewUpdateCheck)
            await self.load(forceRefresh: true)
        }
    }

    /// Checks once a day unless turned off in Settings.
    func checkForUpdatesIfDue() async {
        guard BrewProcess.isInstalled,
              UserDefaults.standard.object(forKey: SettingsKey.checksPackageUpdatesDaily) as? Bool ?? true
        else { return }
        if let lastUpdateCheck, Date().timeIntervalSince(lastUpdateCheck) < Self.automaticCheckInterval {
            return
        }
        await checkForUpdates(background: true)
    }

    // MARK: Upgrade All

    /// The latest upgrade batch — kept after it finishes so failures can be
    /// shown and retried.
    private var upgradeAllOperationID: UUID?

    /// The activity entry of the latest upgrade batch, carrying per-package
    /// progress: which package is upgrading and how many are left.
    var upgradeAllOperation: BrewOperation? {
        upgradeAllOperationID.flatMap(activityStore.operation)
    }

    var isUpgradingAll: Bool {
        upgradeAllOperation?.isRunning == true
    }

    /// Upgrades every outdated package that isn't pinned, one at a time, so
    /// progress can be reported per package and one failure doesn't stop
    /// the rest.
    func upgradeAll() {
        startUpgradeBatch(outdatedPackages.filter(\.canUpgrade))
    }

    /// Runs a new batch with just the packages that failed in `operation`
    /// and are still outdated.
    func retryFailedUpgrades(of operation: BrewOperation) {
        let failedStepIDs = Set(operation.failedSteps.map(\.id))
        startUpgradeBatch(outdatedPackages.filter { failedStepIDs.contains($0.upgradeStep.id) && $0.canUpgrade })
    }

    private func startUpgradeBatch(_ packages: [PackageType]) {
        // Packages busy with another operation would collide with brew's lock.
        let packages = packages.filter { !isBusy($0) }
        guard !packages.isEmpty, !activityStore.isActive(.homebrew) else { return }

        Task {
            await activityStore.perform(
                .upgradeAll(count: packages.count),
                steps: packages.map(\.upgradeStep),
                retry: .custom { operation in self.retryFailedUpgrades(of: operation) }
            ) { activity in
                self.upgradeAllOperationID = activity.id
                var failures: [String] = []
                for package in packages {
                    if try await !Self.runStep(of: package, in: activity) {
                        failures.append(package.identifier)
                    }
                }
                await self.load(forceRefresh: true)
                guard failures.isEmpty else { throw UpgradeBatchFailure(packages: failures) }
            }
        }
    }

    /// Runs one package of a batch and reports whether it upgraded.
    /// Cancellation propagates so the whole batch stops.
    private static func runStep(of package: PackageType, in activity: ActivityContext) async throws -> Bool {
        let stepID = package.upgradeStep.id
        activity.setStep(stepID, .running)
        do {
            switch package {
            case .formula(let formula): try await activity.stream(formula.upgradeOutput())
            case .cask(let cask): try await activity.stream(cask.upgradeOutput())
            }
            activity.setStep(stepID, .succeeded)
            return true
        } catch where !isOperationCancellation(error) {
            activity.setStep(stepID, .failed(reason: error.briefDescription))
            return false
        }
    }

    // MARK: Homebrew Search

    /// Brew matches too broadly below this length to be useful.
    static let minimumSearchLength = 2
    /// Search results described with `brew info`; the rest show names only.
    static let searchDetailLimit = 30
    /// How long typing pauses before Cellar asks brew.
    static let searchDelay: Duration = .milliseconds(300)

    /// Searches Homebrew for the list's query. Results for a query the user
    /// has since changed are dropped.
    func searchHomebrew(_ kind: PackageKind) async {
        let list = list(kind)
        let query = list.trimmedQuery
        guard query.count >= Self.minimumSearchLength else { return }
        list.isSearching = true
        do {
            let results = try await Self.searchHomebrew(query, kind: kind)
            guard list.trimmedQuery == query else { return }
            list.finishSearch(query: query, results: results, error: nil)
        } catch {
            guard list.trimmedQuery == query, !isOperationCancellation(error) else { return }
            list.finishSearch(query: query, results: [], error: error.briefDescription)
        }
    }

    /// Homebrew's packages of `kind` matching `query`. The first
    /// `detailLimit` come with descriptions and versions, the rest with
    /// names only.
    static func searchHomebrew(
        _ query: String,
        kind: PackageKind,
        detailLimit: Int = searchDetailLimit
    ) async throws -> [PackageType] {
        switch kind {
        case .formula: try await Formula.search(for: query, detailLimit: detailLimit).map(PackageType.formula)
        case .cask: try await Cask.search(for: query, detailLimit: detailLimit).map(PackageType.cask)
        }
    }

    // MARK: Private

    /// Runs a package action as an activity, then reloads the package
    /// lists; see `ActivityStore.perform(_:retry:reloading:_:)`.
    @discardableResult
    private func perform(
        _ kind: BrewOperation.Kind,
        _ body: @escaping @MainActor (ActivityContext) async throws -> Void
    ) async -> Bool {
        await activityStore.perform(kind, reloading: { await self.load(forceRefresh: true) }, body)
    }
}

// MARK: - PackageListState

/// What one package page shows besides the installed list: its selection
/// and its Homebrew search.
@Observable
@MainActor
final class PackageListState {

    enum SearchScope: Hashable {
        /// Filter the installed packages.
        case installed
        /// Search everything Homebrew offers.
        case homebrew
    }

    var selection: Set<PackageID> = []
    var searchQuery = ""
    var searchScope = SearchScope.installed

    private(set) var searchResults: [PackageType] = []
    /// The query `searchResults` and `searchError` belong to.
    private(set) var resultsQuery: String?
    private(set) var searchError: String?
    /// Set as soon as the query changes, before the debounce, so the page
    /// says "Searching…" instead of flashing "No Results".
    fileprivate(set) var isSearching = false

    var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The one selected package, which the inspector shows.
    var singleSelection: PackageID? {
        selection.count == 1 ? selection.first : nil
    }

    func select(_ id: PackageID?) {
        selection = id.map { [$0] } ?? []
    }

    func deselect(_ id: PackageID) {
        selection.remove(id)
    }

    /// Call when the query or scope changed, before waiting to search.
    func prepareSearch() {
        isSearching = searchScope == .homebrew && trimmedQuery.count >= PackageStore.minimumSearchLength
    }

    /// Shows the Homebrew results for `query`, e.g. from Quick Open.
    func showHomebrewResults(for query: String) {
        searchQuery = query
        searchScope = .homebrew
    }

    fileprivate func finishSearch(query: String, results: [PackageType], error: String?) {
        searchResults = results
        resultsQuery = query
        searchError = error
        isSearching = false
    }
}

// MARK: - Supporting Types

/// Both package lists, cached together.
nonisolated private struct PackageLists: Codable, Sendable {
    var formulae: [Formula]
    var casks: [Cask]
}

/// Thrown when some packages of an Upgrade All failed; the rest upgraded.
struct UpgradeBatchFailure: LocalizedError {
    let packages: [String]

    var errorDescription: String? {
        "Couldn’t upgrade \(packages.formatted(.list(type: .and)))"
    }
}
