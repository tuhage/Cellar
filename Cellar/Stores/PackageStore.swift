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
final class PackageStore {

    // MARK: Data

    var formulae: [Formula] = []
    var casks: [Cask] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var selectedFormulaId: String?
    var selectedCaskId: String?

    // MARK: Remote Search

    var searchResultFormulae: [Formula] = []
    var searchResultCasks: [Cask] = []
    var isSearchingFormulae = false
    var isSearchingCasks = false
    var installingPackages: Set<String> = []

    // MARK: Cache

    private let persistence = PersistenceService()
    private static let cacheMaxAge: TimeInterval = 300 // 5 minutes
    private static let formulaeCacheFile = "cache-formulae.json"
    private static let casksCacheFile = "cache-casks.json"

    // MARK: Computed

    var filteredFormulae: [Formula] {
        guard !searchQuery.isEmpty else { return formulae }
        let query = searchQuery.localizedLowercase
        return formulae.filter { formula in
            formula.name.localizedCaseInsensitiveContains(query)
                || formula.fullName.localizedCaseInsensitiveContains(query)
                || (formula.desc?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var filteredCasks: [Cask] {
        guard !searchQuery.isEmpty else { return casks }
        let query = searchQuery.localizedLowercase
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upgrade(_ formula: Formula) async {
        isLoading = true
        errorMessage = nil
        do {
            try await formula.upgrade()
            try await refreshFormulae()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upgrade(_ cask: Cask) async {
        isLoading = true
        errorMessage = nil
        do {
            try await cask.upgrade()
            try await refreshCasks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var isUpgradingAll = false
    private var upgradeAllTask: Task<Void, Never>?

    func upgradeAll() {
        upgradeAllTask = Task {
            isUpgradingAll = true
            isLoading = true
            errorMessage = nil

            let formulaeToUpgrade = outdatedFormulae
            let casksToUpgrade = outdatedCasks
            var failures: [String] = []

            for formula in formulaeToUpgrade {
                guard !Task.isCancelled else { break }
                do {
                    try await formula.upgrade()
                } catch {
                    failures.append(formula.name)
                }
            }
            for cask in casksToUpgrade {
                guard !Task.isCancelled else { break }
                do {
                    try await cask.upgrade()
                } catch {
                    failures.append(cask.token)
                }
            }

            do {
                async let loadedFormulae = Formula.all
                async let loadedCasks = Cask.all
                formulae = try await loadedFormulae
                casks = try await loadedCasks
                persistence.saveToCache(formulae, to: Self.formulaeCacheFile)
                persistence.saveToCache(casks, to: Self.casksCacheFile)
            } catch {
                errorMessage = error.localizedDescription
            }

            if Task.isCancelled {
                if errorMessage == nil {
                    errorMessage = "Upgrade cancelled. Some packages may have been upgraded."
                }
            } else if !failures.isEmpty && errorMessage == nil {
                errorMessage = "Failed to upgrade: \(failures.joined(separator: ", "))"
            }

            isLoading = false
            isUpgradingAll = false
            upgradeAllTask = nil
        }
    }

    func cancelUpgradeAll() {
        upgradeAllTask?.cancel()
    }

    func uninstall(_ formula: Formula) async {
        isLoading = true
        errorMessage = nil
        do {
            try await formula.uninstall()
            try await refreshFormulae()
            if selectedFormulaId == formula.id {
                selectedFormulaId = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func uninstall(_ cask: Cask) async {
        isLoading = true
        errorMessage = nil
        do {
            try await cask.uninstall()
            try await refreshCasks()
            if selectedCaskId == cask.id {
                selectedCaskId = nil
            }
        } catch {
            errorMessage = error.localizedDescription
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
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
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
        installingPackages.insert(name)
        do {
            try await Formula.install(name: name)
            try await refreshFormulae()
        } catch {
            errorMessage = error.localizedDescription
        }
        installingPackages.remove(name)
    }

    func installCask(_ cask: Cask) async {
        installingPackages.insert(cask.token)
        do {
            try await cask.install()
            try await refreshCasks()
        } catch {
            errorMessage = error.localizedDescription
        }
        installingPackages.remove(cask.token)
    }

    // MARK: Private

    private func refreshFormulae() async throws {
        formulae = try await Formula.all
        persistence.saveToCache(formulae, to: Self.formulaeCacheFile)
    }

    private func refreshCasks() async throws {
        casks = try await Cask.all
        persistence.saveToCache(casks, to: Self.casksCacheFile)
    }
}
