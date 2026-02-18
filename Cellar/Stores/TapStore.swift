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
    private static let cacheFile = "cache-taps.json"

    // MARK: Computed

    var filteredTaps: [Tap] {
        guard !searchQuery.isEmpty else { return taps }
        return taps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    // MARK: Actions

    /// Loads all Homebrew taps.
    func load(forceRefresh: Bool = false) async {
        let (restored, needsFetch) = persistence.restoreIfNeeded(
            current: taps, from: Self.cacheFile,
            maxAge: Self.cacheMaxAge, forceRefresh: forceRefresh
        )
        taps = restored
        guard needsFetch else { return }

        isLoading = true
        errorMessage = nil
        do {
            try await refreshTaps()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Adds a tap by name and provides a stream for progress output.
    func addTap(_ name: String) {
        isLoading = true
        errorMessage = nil
        let service = BrewService()
        actionStream = service.addTap(name)
    }

    /// Removes a tap and reloads the tap list.
    func removeTap(_ tap: Tap) async {
        isLoading = true
        errorMessage = nil
        do {
            try await tap.remove()
            try await refreshTaps()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Dismisses the active action stream overlay.
    func dismissAction() {
        actionStream = nil
        isLoading = false
    }

    // MARK: Private

    private func refreshTaps() async throws {
        taps = try await Tap.all
        persistence.saveToCache(taps, to: Self.cacheFile)
    }
}
