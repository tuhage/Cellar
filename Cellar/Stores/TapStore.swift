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

    // MARK: Cache

    private let persistence = PersistenceService()
    private static let cacheMaxAge: TimeInterval = 300

    // MARK: Computed

    var filteredTaps: [Tap] {
        guard !searchQuery.isEmpty else { return taps }
        return taps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    // MARK: Actions

    /// Loads all Homebrew taps.
    func load(forceRefresh: Bool = false) async {
        // Restore from disk if we have nothing to display yet.
        if taps.isEmpty, let cached = persistence.loadCached([Tap].self, from: "cache-taps.json", maxAge: Self.cacheMaxAge) {
            taps = cached.data
            if cached.isFresh && !forceRefresh { return }
        } else if !forceRefresh, !taps.isEmpty,
                  let cached = persistence.loadCached([Tap].self, from: "cache-taps.json", maxAge: Self.cacheMaxAge),
                  cached.isFresh {
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            taps = try await Tap.all
            persistence.saveToCache(taps, to: "cache-taps.json")
        } catch {
            if taps.isEmpty { errorMessage = error.localizedDescription }
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
            persistence.saveToCache(taps, to: "cache-taps.json")
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
