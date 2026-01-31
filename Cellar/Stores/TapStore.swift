import Foundation
import Observation
import CellarCore

// MARK: - TapStore

/// Manages the state for Homebrew taps.
///
/// Coordinates loading, filtering, and add/remove operations.
/// Views bind to this store for the tap list UI.
@Observable
@MainActor
final class TapStore {

    // MARK: Data

    var taps: [Tap] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var actionStream: AsyncThrowingStream<String, Error>?

    // MARK: Computed

    var filteredTaps: [Tap] {
        guard !searchQuery.isEmpty else { return taps }
        return taps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    // MARK: Actions

    /// Loads all Homebrew taps.
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            taps = try await Tap.all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Adds a tap by name and provides a stream for progress output.
    func addTap(_ name: String) {
        let service = BrewService()
        actionStream = service.addTap(name)
    }

    /// Removes a tap and reloads the tap list.
    func removeTap(_ tap: Tap) async {
        isLoading = true
        errorMessage = nil
        do {
            try await tap.remove()
            taps = try await Tap.all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Dismisses the active action stream overlay.
    func dismissAction() {
        actionStream = nil
    }
}
