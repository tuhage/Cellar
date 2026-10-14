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
    var formulaSearchQuery = ""
    var caskSearchQuery = ""
    var selectedFormulaId: String?
    var selectedCaskId: String?
    /// Set to show the Upgrade All preview from anywhere in the app.
    var isUpgradePreviewPresented = false

    // MARK: Remote Search

    var searchResultFormulae: [Formula] = []
    var searchResultCasks: [Cask] = []
    var isSearchingFormulae = false
    var isSearchingCasks = false

    // MARK: Dependencies

    let activityStore: ActivityStore
    private static let cache = CachePolicy(fileName: "cache-packages.json")

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
    }

    // MARK: Computed

    var filteredFormulae: [Formula] {
        guard !formulaSearchQuery.isEmpty else { return formulae }
        return formulae.filter { formula in
            formula.name.localizedCaseInsensitiveContains(formulaSearchQuery)
                || formula.fullName.localizedCaseInsensitiveContains(formulaSearchQuery)
                || (formula.desc?.localizedCaseInsensitiveContains(formulaSearchQuery) ?? false)
        }
    }

    var filteredCasks: [Cask] {
        guard !caskSearchQuery.isEmpty else { return casks }
        return casks.filter { cask in
            cask.token.localizedCaseInsensitiveContains(caskSearchQuery)
                || cask.displayName.localizedCaseInsensitiveContains(caskSearchQuery)
                || (cask.desc?.localizedCaseInsensitiveContains(caskSearchQuery) ?? false)
        }
    }

    var outdatedFormulae: [Formula] {
        formulae.filter(\.outdated)
    }

    var outdatedCasks: [Cask] {
        casks.filter(\.outdated)
    }

    var totalOutdated: Int {
        outdatedFormulae.count + outdatedCasks.count
    }

    var availableFormulae: [Formula] {
        let installedNames = Set(formulae.map(\.name))
        return searchResultFormulae.filter { !installedNames.contains($0.name) }
    }

    var availableCasks: [Cask] {
        let installedTokens = Set(casks.map(\.token))
        return searchResultCasks.filter { !installedTokens.contains($0.token) }
    }

    // MARK: Loading

    func loadAll(forceRefresh: Bool = false) async {
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

    // MARK: Package Actions

    func installFormula(name: String) async {
        await run(.install(name: name, isCask: false)) { activity in
            try await activity.stream(Formula.installOutput(name: name))
        }
    }

    func installCask(_ cask: Cask) async {
        await run(.install(name: cask.token, isCask: true)) { activity in
            try await activity.stream(cask.installOutput())
        }
    }

    func upgrade(_ formula: Formula) async {
        await run(.upgrade(name: formula.name, isCask: false)) { activity in
            try await activity.stream(formula.upgradeOutput())
        }
    }

    func upgrade(_ cask: Cask) async {
        await run(.upgrade(name: cask.token, isCask: true)) { activity in
            try await activity.stream(cask.upgradeOutput())
        }
    }

    func uninstall(_ formula: Formula, force: Bool = false) async {
        let succeeded = await run(.uninstall(name: formula.name, isCask: false)) { _ in
            try await formula.uninstall(force: force)
        }
        if succeeded, selectedFormulaId == formula.id {
            selectedFormulaId = nil
        }
    }

    func uninstall(_ cask: Cask, force: Bool = false) async {
        let succeeded = await run(.uninstall(name: cask.token, isCask: true)) { _ in
            try await cask.uninstall(force: force)
        }
        if succeeded, selectedCaskId == cask.id {
            selectedCaskId = nil
        }
    }

    func pin(_ formula: Formula) async {
        await run(.pin(name: formula.name)) { _ in try await formula.pin() }
    }

    func unpin(_ formula: Formula) async {
        await run(.unpin(name: formula.name)) { _ in try await formula.unpin() }
    }

    // MARK: Update Check

    /// When Cellar last ran `brew update`.
    private(set) var lastUpdateCheck = UserDefaults.standard.object(forKey: PackageStore.lastUpdateCheckKey) as? Date

    private static let lastUpdateCheckKey = "lastHomebrewUpdateCheck"
    /// Matches brew's own auto-update interval.
    private static let automaticCheckInterval: TimeInterval = 86_400
    static let automaticCheckSettingKey = "checksPackageUpdatesAutomatically"

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
            UserDefaults.standard.set(checkedAt, forKey: Self.lastUpdateCheckKey)
            await self.loadAll(forceRefresh: true)
        }
    }

    /// Checks once a day unless turned off in Settings.
    func checkForUpdatesIfDue() async {
        guard BrewProcess.isInstalled,
              UserDefaults.standard.object(forKey: Self.automaticCheckSettingKey) as? Bool ?? true
        else { return }
        if let lastUpdateCheck, Date().timeIntervalSince(lastUpdateCheck) < Self.automaticCheckInterval {
            return
        }
        await checkForUpdates(background: true)
    }

    // MARK: Upgrade All

    /// The latest Upgrade All — kept after it finishes so failures can be
    /// shown and retried.
    private var upgradeAllOperationID: UUID?

    /// The activity entry of the latest Upgrade All, carrying per-package
    /// progress: which package is upgrading and how many are left.
    var upgradeAllOperation: BrewOperation? {
        upgradeAllOperationID.flatMap(activityStore.operation)
    }

    var isUpgradingAll: Bool {
        upgradeAllOperation?.isRunning == true
    }

    /// Outdated formulae Upgrade All will touch. Pinned ones are skipped
    /// because brew refuses to upgrade them.
    var upgradableFormulae: [Formula] {
        outdatedFormulae.filter { !$0.pinned }
    }

    var pinnedOutdatedCount: Int {
        outdatedFormulae.count(where: \.pinned)
    }

    /// Upgrades packages one at a time so progress can be reported per
    /// package and one failure doesn't stop the rest.
    func upgradeAll() {
        startUpgradeBatch(formulae: upgradableFormulae, casks: outdatedCasks)
    }

    /// Runs a new batch with just the packages that failed in `operation`
    /// and are still outdated.
    func retryFailedUpgrades(of operation: BrewOperation) {
        let failed = operation.failedSteps
        let formulaNames = Set(failed.filter { !$0.isCask }.map(\.name))
        let caskTokens = Set(failed.filter(\.isCask).map(\.name))
        startUpgradeBatch(
            formulae: upgradableFormulae.filter { formulaNames.contains($0.name) },
            casks: outdatedCasks.filter { caskTokens.contains($0.token) }
        )
    }

    func cancelUpgradeAll() {
        guard let upgradeAllOperationID else { return }
        activityStore.cancel(upgradeAllOperationID)
    }

    private func startUpgradeBatch(formulae: [Formula], casks: [Cask]) {
        // Packages busy with another operation would collide with brew's lock.
        let formulae = formulae.filter { !activityStore.isActive(.package($0.name)) }
        let casks = casks.filter { !activityStore.isActive(.package($0.token)) }
        let steps = formulae.map(BrewOperation.Step.init(formula:)) + casks.map(BrewOperation.Step.init(cask:))
        guard !steps.isEmpty, !activityStore.isActive(.homebrew) else { return }

        Task {
            await activityStore.perform(
                .upgradeAll(count: steps.count),
                steps: steps,
                retry: .custom { operation in self.retryFailedUpgrades(of: operation) }
            ) { activity in
                self.upgradeAllOperationID = activity.id
                var failures: [String] = []
                for formula in formulae {
                    let stepID = BrewOperation.Step.id(name: formula.name, isCask: false)
                    if try await !Self.runStep(stepID, in: activity, output: formula.upgradeOutput) {
                        failures.append(formula.name)
                    }
                }
                for cask in casks {
                    let stepID = BrewOperation.Step.id(name: cask.token, isCask: true)
                    if try await !Self.runStep(stepID, in: activity, output: cask.upgradeOutput) {
                        failures.append(cask.token)
                    }
                }
                await self.loadAll(forceRefresh: true)
                guard failures.isEmpty else { throw UpgradeBatchFailure(packages: failures) }
            }
        }
    }

    /// Runs one package of a batch and reports whether it upgraded.
    /// Cancellation propagates so the whole batch stops.
    private static func runStep(
        _ stepID: String,
        in activity: ActivityContext,
        output: () -> AsyncThrowingStream<String, Error>
    ) async throws -> Bool {
        activity.setStep(stepID, .running)
        do {
            try await activity.stream(output())
            activity.setStep(stepID, .succeeded)
            return true
        } catch where !isOperationCancellation(error) {
            activity.setStep(stepID, .failed(reason: error.briefDescription))
            return false
        }
    }

    // MARK: Remote Search

    func searchRemoteFormulae() async {
        let query = formulaSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResultFormulae = []
            return
        }
        isSearchingFormulae = true
        searchResultFormulae = (try? await Formula.search(for: query)) ?? []
        isSearchingFormulae = false
    }

    func searchRemoteCasks() async {
        let query = caskSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResultCasks = []
            return
        }
        isSearchingCasks = true
        searchResultCasks = (try? await Cask.search(for: query)) ?? []
        isSearchingCasks = false
    }

    // MARK: Private

    /// Runs a package action as an activity and reloads the lists after it
    /// succeeded. Returns whether it succeeded.
    @discardableResult
    private func run(
        _ kind: BrewOperation.Kind,
        _ body: @escaping @MainActor (ActivityContext) async throws -> Void
    ) async -> Bool {
        await activityStore.perform(kind) { activity in
            try await body(activity)
            await self.loadAll(forceRefresh: true)
        } != nil
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
