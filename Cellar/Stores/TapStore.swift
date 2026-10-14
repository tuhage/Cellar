import Foundation
import Observation
import CellarCore

// MARK: - TapStore

/// Installed Homebrew taps and the actions that add or remove them.
@Observable
@MainActor
final class TapStore: LoadableStore {

    // MARK: Data

    var taps: [Tap] = []

    // MARK: State

    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var searchQuery = ""

    // MARK: Dependencies

    let activityStore: ActivityStore
    private static let cache = CachePolicy(fileName: "cache-taps.json")

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
    }

    // MARK: Computed

    var filteredTaps: [Tap] {
        guard !searchQuery.isEmpty else { return taps }
        return taps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    /// The tap being added or removed, if any.
    var runningOperation: BrewOperation? {
        activityStore.runningOperation { operation in
            if case .tap = operation.kind.target { return true }
            return false
        }
    }

    // MARK: Actions

    func load(forceRefresh: Bool = false) async {
        await load(
            cache: Self.cache,
            force: forceRefresh,
            failureMessage: "Taps couldn’t be loaded."
        ) {
            try await Tap.all
        } apply: { taps in
            self.taps = taps
        }
    }

    /// Adds a tap; progress and output appear in Activity.
    func addTap(_ name: String) async {
        await activityStore.perform(.tapAdd(name: name)) { activity in
            try await activity.stream(BrewService.shared.addTap(name))
            await self.load(forceRefresh: true)
        }
    }

    func removeTap(_ tap: Tap) async {
        await activityStore.perform(.tapRemove(name: tap.name)) { _ in
            try await tap.remove()
            await self.load(forceRefresh: true)
        }
    }
}
