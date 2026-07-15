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
final class TapStore: LoadableStore {

    // MARK: Data

    var taps: [Tap] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var actionStream: AsyncThrowingStream<String, Error>?

    // MARK: Activity

    var activityStore: ActivityStore?

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
            if !isOperationCancellation(error) {
                errorMessage = "Taps couldn’t be loaded. Please try again."
            }
        }
        isLoading = false
    }

    /// Adds a tap by name and provides a stream for progress output.
    func addTap(_ name: String) {
        guard activityStore?.isActive(target: name) != true else {
            errorMessage = "\(name) is already in progress"
            return
        }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .tapAdd(url: name))
        let underlying = BrewService.shared.addTap(name)
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let task = Task {
            do {
                for try await line in underlying {
                    if let opID { activityStore?.appendLog(opID, line) }
                    continuation.yield(line)
                }
                continuation.finish()
                if let opID { activityStore?.setStatus(opID, .succeeded) }
                await load(forceRefresh: true)
            } catch {
                continuation.finish(throwing: error)
                if let opID {
                    activityStore?.setStatus(
                        opID,
                        Task.isCancelled ? .cancelled : .failed(reason: error.localizedDescription)
                    )
                }
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
        if let opID {
            activityStore?.setCancellationHandler(opID) { task.cancel() }
        }
        actionStream = stream
    }

    /// Removes a tap and reloads the tap list.
    func removeTap(_ tap: Tap) async {
        guard activityStore?.isActive(target: tap.name) != true else { return }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .tapRemove(name: tap.name))
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                try await tap.remove()
            }
            try await refreshTaps()
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
