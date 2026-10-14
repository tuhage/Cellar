import Foundation
import Observation
import CellarCore

// MARK: - PackageStore

/// Manages the state for installed formulae and casks.
///
/// Coordinates loading, filtering, and mutation operations across both
/// package types. Views bind to this store for the main package list UI.
@Observable
@MainActor
final class PackageStore: LoadableStore {

    // MARK: Data

    var formulae: [Formula] = []
    var casks: [Cask] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var formulaSearchQuery = ""
    var caskSearchQuery = ""
    var selectedFormulaId: String?
    var selectedCaskId: String?

    // MARK: Remote Search

    var searchResultFormulae: [Formula] = []
    var searchResultCasks: [Cask] = []
    var isSearchingFormulae = false
    var isSearchingCasks = false
    var installingPackages: Set<String> = []

    // MARK: Activity

    var activityStore: ActivityStore?

    // MARK: Cache

    private let persistence = PersistenceService()
    private static let cacheMaxAge: TimeInterval = 300 // 5 minutes
    private static let formulaeCacheFile = "cache-formulae.json"
    private static let casksCacheFile = "cache-casks.json"

    // MARK: Computed

    var filteredFormulae: [Formula] {
        guard !formulaSearchQuery.isEmpty else { return formulae }
        let query = formulaSearchQuery.localizedLowercase
        return formulae.filter { formula in
            formula.name.localizedCaseInsensitiveContains(query)
                || formula.fullName.localizedCaseInsensitiveContains(query)
                || (formula.desc?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var filteredCasks: [Cask] {
        guard !caskSearchQuery.isEmpty else { return casks }
        let query = caskSearchQuery.localizedLowercase
        return casks.filter { cask in
            cask.token.localizedCaseInsensitiveContains(query)
                || cask.displayName.localizedCaseInsensitiveContains(query)
                || (cask.desc?.localizedCaseInsensitiveContains(query) ?? false)
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

    // MARK: Actions

    func loadFormulae(forceRefresh: Bool = false) async {
        let (restored, needsFetch) = persistence.restoreIfNeeded(
            current: formulae, from: Self.formulaeCacheFile,
            maxAge: Self.cacheMaxAge, forceRefresh: forceRefresh
        )
        formulae = restored
        guard needsFetch else { return }

        isLoading = true
        errorMessage = nil
        do {
            formulae = try await Formula.all
            persistence.saveToCache(formulae, to: Self.formulaeCacheFile)
        } catch {
            if !isOperationCancellation(error) {
                errorMessage = "Formulae couldn’t be loaded. Please try again."
            }
        }
        isLoading = false
    }

    func loadCasks(forceRefresh: Bool = false) async {
        let (restored, needsFetch) = persistence.restoreIfNeeded(
            current: casks, from: Self.casksCacheFile,
            maxAge: Self.cacheMaxAge, forceRefresh: forceRefresh
        )
        casks = restored
        guard needsFetch else { return }

        isLoading = true
        errorMessage = nil
        do {
            casks = try await Cask.all
            persistence.saveToCache(casks, to: Self.casksCacheFile)
        } catch {
            if !isOperationCancellation(error) {
                errorMessage = "Casks couldn’t be loaded. Please try again."
            }
        }
        isLoading = false
    }

    func loadAll(forceRefresh: Bool = false) async {
        let (restoredFormulae, formulaeNeedsFetch) = persistence.restoreIfNeeded(
            current: formulae, from: Self.formulaeCacheFile,
            maxAge: Self.cacheMaxAge, forceRefresh: forceRefresh
        )
        let (restoredCasks, casksNeedsFetch) = persistence.restoreIfNeeded(
            current: casks, from: Self.casksCacheFile,
            maxAge: Self.cacheMaxAge, forceRefresh: forceRefresh
        )
        formulae = restoredFormulae
        casks = restoredCasks
        guard formulaeNeedsFetch || casksNeedsFetch else { return }

        isLoading = true
        errorMessage = nil
        do {
            async let loadedFormulae = Formula.all
            async let loadedCasks = Cask.all
            formulae = try await loadedFormulae
            casks = try await loadedCasks

            persistence.saveToCache(formulae, to: Self.formulaeCacheFile)
            persistence.saveToCache(casks, to: Self.casksCacheFile)

            await SpotlightService.shared.indexAll(formulae: formulae, casks: casks)
        } catch {
            if !isOperationCancellation(error) {
                errorMessage = "Homebrew packages couldn’t be loaded. Please try again."
            }
        }
        isLoading = false
    }

    func upgrade(_ formula: Formula) async {
        guard activityStore?.isActive(target: formula.name) != true else {
            errorMessage = "\(formula.name) is already in progress"
            return
        }
        let opID = activityStore?.register(kind: .upgrade(name: formula.name, isCask: false))
        isLoading = true
        errorMessage = nil
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                try await self.drain(formula.upgradeOutput(), into: opID)
            }
            try await refreshFormulae()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func upgrade(_ cask: Cask) async {
        guard activityStore?.isActive(target: cask.token) != true else {
            errorMessage = "\(cask.token) is already in progress"
            return
        }
        let opID = activityStore?.register(kind: .upgrade(name: cask.token, isCask: true))
        isLoading = true
        errorMessage = nil
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                try await self.drain(cask.upgradeOutput(), into: opID)
            }
            try await refreshCasks()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    // MARK: Update Check

    var isCheckingForUpdates = false
    /// When Cellar last ran `brew update`.
    private(set) var lastUpdateCheck = UserDefaults.standard.object(forKey: PackageStore.lastUpdateCheckKey) as? Date

    private static let lastUpdateCheckKey = "lastHomebrewUpdateCheck"
    /// Matches brew's own auto-update interval.
    private static let automaticCheckInterval: TimeInterval = 86_400
    static let automaticCheckSettingKey = "checksPackageUpdatesAutomatically"

    /// Runs `brew update` so outdated packages reflect what is actually
    /// available — every other brew call runs with auto-update off — then
    /// reloads the package lists.
    func checkForUpdates() async {
        guard !isCheckingForUpdates, !isUpgradingAll else { return }
        isCheckingForUpdates = true
        let opID = activityStore?.register(kind: .brewUpdate)
        do {
            let completed = try await withCancellableActivity(activityStore, id: opID) {
                try await self.drain(BrewService.shared.update(), into: opID)
                // A cancelled stream ends quietly instead of throwing.
                return !Task.isCancelled
            }
            guard completed else { throw CancellationError() }
            let checkedAt = Date()
            lastUpdateCheck = checkedAt
            UserDefaults.standard.set(checkedAt, forKey: Self.lastUpdateCheckKey)
            await loadAll(forceRefresh: true)
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: Self.failureSummary(of: error)))
            }
        }
        isCheckingForUpdates = false
    }

    /// Checks once a day unless turned off in Settings.
    func checkForUpdatesIfDue() async {
        guard BrewProcess.isInstalled,
              UserDefaults.standard.object(forKey: Self.automaticCheckSettingKey) as? Bool ?? true
        else { return }
        if let lastUpdateCheck, Date().timeIntervalSince(lastUpdateCheck) < Self.automaticCheckInterval {
            return
        }
        await checkForUpdates()
    }

    // MARK: Upgrade All

    var isUpgradingAll = false
    private var upgradeAllTask: Task<Void, Never>?
    /// The latest Upgrade All — kept after it finishes so failures can be
    /// shown and retried.
    private var upgradeAllOperationID: UUID?

    /// The activity entry of the latest Upgrade All, carrying per-package
    /// progress: which package is upgrading and how many are left.
    var upgradeAllOperation: BrewOperation? {
        guard let upgradeAllOperationID else { return nil }
        return activityStore?.operations.first { $0.id == upgradeAllOperationID }
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

    /// Whether a finished batch has failed packages that are still outdated.
    func canRetryFailedUpgrades(of operation: BrewOperation) -> Bool {
        guard !isUpgradingAll, !operation.isRunning else { return false }
        let (formulae, casks) = failedPackages(of: operation)
        return !formulae.isEmpty || !casks.isEmpty
    }

    /// Runs a new batch with just the packages that failed in `operation`.
    func retryFailedUpgrades(of operation: BrewOperation) {
        let (formulae, casks) = failedPackages(of: operation)
        startUpgradeBatch(formulae: formulae, casks: casks)
    }

    private func failedPackages(of operation: BrewOperation) -> (formulae: [Formula], casks: [Cask]) {
        let failed = operation.failedSteps
        let formulaNames = Set(failed.filter { !$0.isCask }.map(\.name))
        let caskTokens = Set(failed.filter(\.isCask).map(\.name))
        return (
            upgradableFormulae.filter { formulaNames.contains($0.name) },
            outdatedCasks.filter { caskTokens.contains($0.token) }
        )
    }

    private func startUpgradeBatch(formulae formulaeToUpgrade: [Formula], casks casksToUpgrade: [Cask]) {
        guard upgradeAllTask == nil, !isCheckingForUpdates else { return }
        let steps = formulaeToUpgrade.map(BrewOperation.Step.init(formula:))
            + casksToUpgrade.map(BrewOperation.Step.init(cask:))
        guard !steps.isEmpty else { return }

        let opID = activityStore?.register(kind: .upgradeAll(count: steps.count), steps: steps)
        upgradeAllOperationID = opID
        isUpgradingAll = true
        isLoading = true
        errorMessage = nil

        let task = Task {
            var failures: [String] = []

            for formula in formulaeToUpgrade {
                guard !Task.isCancelled else { break }
                let result = await runUpgradeStep(
                    BrewOperation.Step.id(name: formula.name, isCask: false),
                    of: opID,
                    output: { formula.upgradeOutput() }
                )
                if case .failed = result { failures.append(formula.name) }
            }
            for cask in casksToUpgrade {
                guard !Task.isCancelled else { break }
                let result = await runUpgradeStep(
                    BrewOperation.Step.id(name: cask.token, isCask: true),
                    of: opID,
                    output: { cask.upgradeOutput() }
                )
                if case .failed = result { failures.append(cask.token) }
            }

            let wasCancelled = Task.isCancelled
            if wasCancelled, let opID { activityStore?.cancelUnfinishedSteps(opID) }
            await finishUpgradeAll(opID: opID, failures: failures, wasCancelled: wasCancelled)
        }
        upgradeAllTask = task
        if let opID {
            activityStore?.setCancellationHandler(opID) { task.cancel() }
        }
    }

    func cancelUpgradeAll() {
        if let upgradeAllOperationID, activityStore?.canCancel(upgradeAllOperationID) == true {
            activityStore?.cancel(upgradeAllOperationID)
        } else {
            upgradeAllTask?.cancel()
        }
    }

    /// Runs one package of an Upgrade All batch, streaming brew's output into
    /// the activity log, and returns how the package ended up.
    private func runUpgradeStep(
        _ stepID: String,
        of opID: UUID?,
        output: () -> AsyncThrowingStream<String, Error>
    ) async -> BrewOperation.StepStatus {
        if let opID { activityStore?.setStepStatus(opID, step: stepID, .running) }

        let result: BrewOperation.StepStatus
        do {
            try await drain(output(), into: opID)
            // A cancelled stream ends quietly instead of throwing.
            result = Task.isCancelled ? .cancelled : .succeeded
        } catch {
            if Task.isCancelled || isOperationCancellation(error) {
                result = .cancelled
            } else {
                // brew's stderr is already in the log: upgrades stream it.
                result = .failed(reason: Self.failureSummary(of: error))
            }
        }

        if let opID { activityStore?.setStepStatus(opID, step: stepID, result) }
        return result
    }

    private func finishUpgradeAll(opID: UUID?, failures: [String], wasCancelled: Bool) async {
        // A separate task so the refresh still runs after Cancel: packages
        // upgraded before cancelling should drop off the outdated list.
        let refresh = Task { () async throws -> ([Formula], [Cask]) in
            async let loadedFormulae = Formula.all
            async let loadedCasks = Cask.all
            return try await (loadedFormulae, loadedCasks)
        }
        do {
            (formulae, casks) = try await refresh.value
            persistence.saveToCache(formulae, to: Self.formulaeCacheFile)
            persistence.saveToCache(casks, to: Self.casksCacheFile)
        } catch {
            errorMessage = error.localizedDescription
        }

        if wasCancelled {
            if let opID { activityStore?.setStatus(opID, .cancelled) }
            if errorMessage == nil {
                errorMessage = "Upgrade cancelled. Some packages may have been upgraded."
            }
        } else if !failures.isEmpty {
            let reason = "Failed to upgrade: \(failures.joined(separator: ", "))"
            if let opID { activityStore?.setStatus(opID, .failed(reason: reason)) }
            if errorMessage == nil { errorMessage = reason }
        } else {
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        }

        isLoading = false
        isUpgradingAll = false
        upgradeAllTask = nil
    }

    /// The most useful part of a brew failure — its last `Error:` line —
    /// instead of the whole stderr dump.
    private static func failureSummary(of error: Error) -> String {
        guard case BrewError.processFailure(_, let stderr) = error else {
            return error.localizedDescription
        }
        let lines = stderr
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let errorLine = lines.last(where: { $0.hasPrefix("Error:") }) {
            return errorLine.dropFirst("Error:".count).trimmingCharacters(in: .whitespaces)
        }
        return lines.last ?? error.localizedDescription
    }

    func uninstall(_ formula: Formula, force: Bool = false) async {
        guard activityStore?.isActive(target: formula.name) != true else {
            errorMessage = "\(formula.name) is already in progress"
            return
        }
        let opID = activityStore?.register(kind: .uninstall(name: formula.name, isCask: false))
        isLoading = true
        errorMessage = nil
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                try await formula.uninstall(force: force)
            }
            try await refreshFormulae()
            if selectedFormulaId == formula.id {
                selectedFormulaId = nil
            }
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func uninstall(_ cask: Cask, force: Bool = false) async {
        guard activityStore?.isActive(target: cask.token) != true else {
            errorMessage = "\(cask.token) is already in progress"
            return
        }
        let opID = activityStore?.register(kind: .uninstall(name: cask.token, isCask: true))
        isLoading = true
        errorMessage = nil
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                try await cask.uninstall(force: force)
            }
            try await refreshCasks()
            if selectedCaskId == cask.id {
                selectedCaskId = nil
            }
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func pin(_ formula: Formula) async {
        errorMessage = nil
        do {
            try await formula.pin()
            try await refreshFormulae()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unpin(_ formula: Formula) async {
        errorMessage = nil
        do {
            try await formula.unpin()
            try await refreshFormulae()
        } catch {
            errorMessage = error.localizedDescription
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
        do {
            searchResultFormulae = try await Formula.search(for: query)
        } catch {
            searchResultFormulae = []
        }
        isSearchingFormulae = false
    }

    func searchRemoteCasks() async {
        let query = caskSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResultCasks = []
            return
        }
        isSearchingCasks = true
        do {
            searchResultCasks = try await Cask.search(for: query)
        } catch {
            searchResultCasks = []
        }
        isSearchingCasks = false
    }

    // MARK: Install

    func installFormula(name: String) async {
        guard activityStore?.isActive(target: name) != true else {
            errorMessage = "\(name) is already in progress"
            return
        }
        let opID = activityStore?.register(kind: .install(name: name, isCask: false))
        installingPackages.insert(name)
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                try await Formula.install(name: name)
            }
            try await refreshFormulae()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) { errorMessage = error.localizedDescription }
        }
        installingPackages.remove(name)
    }

    func installCask(_ cask: Cask) async {
        guard activityStore?.isActive(target: cask.token) != true else {
            errorMessage = "\(cask.token) is already in progress"
            return
        }
        let opID = activityStore?.register(kind: .install(name: cask.token, isCask: true))
        installingPackages.insert(cask.token)
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                try await cask.install()
            }
            try await refreshCasks()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) { errorMessage = error.localizedDescription }
        }
        installingPackages.remove(cask.token)
    }

    // MARK: Private

    /// Forwards each line of brew's output to the operation's activity log.
    private func drain(_ output: AsyncThrowingStream<String, Error>, into opID: UUID?) async throws {
        for try await line in output {
            if let opID { activityStore?.appendLog(opID, line) }
        }
    }

    private func refreshFormulae() async throws {
        formulae = try await Formula.all
        persistence.saveToCache(formulae, to: Self.formulaeCacheFile)
    }

    private func refreshCasks() async throws {
        casks = try await Cask.all
        persistence.saveToCache(casks, to: Self.casksCacheFile)
    }
}
