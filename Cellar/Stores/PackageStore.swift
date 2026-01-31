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

    func loadFormulae() async {
        isLoading = true
        errorMessage = nil
        do {
            formulae = try await Formula.all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadCasks() async {
        isLoading = true
        errorMessage = nil
        do {
            casks = try await Cask.all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        do {
            async let loadedFormulae = Formula.all
            async let loadedCasks = Cask.all
            formulae = try await loadedFormulae
            casks = try await loadedCasks

            // Re-index Spotlight
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
            formulae = try await Formula.all
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
            casks = try await Cask.all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upgradeAll() async {
        isLoading = true
        errorMessage = nil

        let formulaeToUpgrade = outdatedFormulae
        let casksToUpgrade = outdatedCasks
        var failures: [String] = []

        for formula in formulaeToUpgrade {
            do {
                try await formula.upgrade()
            } catch {
                failures.append(formula.name)
            }
        }
        for cask in casksToUpgrade {
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
        } catch {
            errorMessage = error.localizedDescription
        }

        if !failures.isEmpty && errorMessage == nil {
            errorMessage = "Failed to upgrade: \(failures.joined(separator: ", "))"
        }

        isLoading = false
    }

    func uninstall(_ formula: Formula) async {
        isLoading = true
        errorMessage = nil
        do {
            try await formula.uninstall()
            formulae = try await Formula.all
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
            casks = try await Cask.all
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
            formulae = try await Formula.all
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unpin(_ formula: Formula) async {
        errorMessage = nil
        do {
            try await formula.unpin()
            formulae = try await Formula.all
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
            let service = BrewService()
            for try await _ in service.install(name, isCask: false) {}
            formulae = try await Formula.all
        } catch {
            errorMessage = error.localizedDescription
        }
        installingPackages.remove(name)
    }

    func installCask(_ cask: Cask) async {
        installingPackages.insert(cask.token)
        do {
            try await cask.install()
            casks = try await Cask.all
        } catch {
            errorMessage = error.localizedDescription
        }
        installingPackages.remove(cask.token)
    }
}
