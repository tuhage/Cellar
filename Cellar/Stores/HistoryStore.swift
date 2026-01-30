import Foundation
import Observation
import CellarCore

// MARK: - HistoryStore

/// Manages the history of Homebrew actions performed through the app.
///
/// Persists events to disk via `PersistenceService` and provides
/// filtering by event type and search query. Views bind to this
/// store for the history timeline UI.
@Observable
@MainActor
final class HistoryStore {

    // MARK: Data

    var events: [HistoryEvent] = []

    // MARK: State

    var filterType: HistoryEventType?
    var searchQuery: String = ""
    var isLoading = false
    var errorMessage: String?

    // MARK: Dependencies

    private let persistence = PersistenceService()

    private static let fileName = "history_events.json"

    // MARK: Computed

    /// Events filtered by the current type filter and search query, sorted newest first.
    var filteredEvents: [HistoryEvent] {
        var result = events

        if let filterType {
            result = result.filter { $0.eventType == filterType }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.localizedLowercase
            result = result.filter { event in
                event.packageName.localizedCaseInsensitiveContains(query)
                    || event.summary.localizedCaseInsensitiveContains(query)
                    || (event.details?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        return result.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: Actions

    /// Loads events from persistent storage.
    func load() {
        isLoading = true
        errorMessage = nil
        events = persistence.loadOrDefault(
            [HistoryEvent].self,
            from: Self.fileName,
            default: []
        )
        isLoading = false
    }

    /// Records a new event, appends it to the list, and saves to disk.
    func record(_ event: HistoryEvent) {
        events.append(event)
        save()
    }

    /// Removes all history events and deletes the persisted file.
    func clearHistory() {
        events.removeAll()
        do {
            try persistence.delete(fileName: Self.fileName)
        } catch {
            errorMessage = "Failed to clear history: \(error.localizedDescription)"
        }
    }

    // MARK: Convenience Methods

    /// Records a package installation event.
    func recordInstall(package name: String, version: String) {
        let event = HistoryEvent(
            eventType: .installed,
            packageName: name,
            toVersion: version
        )
        record(event)
    }

    /// Records a package uninstallation event.
    func recordUninstall(package name: String) {
        let event = HistoryEvent(
            eventType: .uninstalled,
            packageName: name
        )
        record(event)
    }

    /// Records a package upgrade event.
    func recordUpgrade(package name: String, from oldVersion: String, to newVersion: String) {
        let event = HistoryEvent(
            eventType: .upgraded,
            packageName: name,
            fromVersion: oldVersion,
            toVersion: newVersion
        )
        record(event)
    }

    /// Records a service start event.
    func recordServiceStart(service name: String) {
        let event = HistoryEvent(
            eventType: .serviceStarted,
            packageName: name
        )
        record(event)
    }

    /// Records a service stop event.
    func recordServiceStop(service name: String) {
        let event = HistoryEvent(
            eventType: .serviceStopped,
            packageName: name
        )
        record(event)
    }

    // MARK: Private

    /// Persists the current events array to disk.
    private func save() {
        do {
            try persistence.save(events, to: Self.fileName)
        } catch {
            errorMessage = "Failed to save history: \(error.localizedDescription)"
        }
    }
}
