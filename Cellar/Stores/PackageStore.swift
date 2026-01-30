import Foundation
import Observation

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
}
