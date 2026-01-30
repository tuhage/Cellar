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

    /// Loads all installed formulae from Homebrew.
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

    /// Loads all installed casks from Homebrew.
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

    /// Loads both formulae and casks concurrently.
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

    /// Upgrades a single formula and reloads the formulae list.
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

    /// Upgrades a single cask and reloads the cask list.
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

    /// Upgrades all outdated formulae and casks, then reloads everything.
    func upgradeAll() async {
        isLoading = true
        errorMessage = nil
        do {
            for formula in outdatedFormulae {
                try await formula.upgrade()
            }
            for cask in outdatedCasks {
                try await cask.upgrade()
            }
            async let loadedFormulae = Formula.all
            async let loadedCasks = Cask.all
            formulae = try await loadedFormulae
            casks = try await loadedCasks
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Uninstalls a formula and reloads the formulae list.
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

    /// Uninstalls a cask and reloads the cask list.
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

    /// Pins a formula to prevent it from being upgraded.
    func pin(_ formula: Formula) async {
        errorMessage = nil
        do {
            try await formula.pin()
            formulae = try await Formula.all
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Unpins a formula so it can be upgraded again.
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
