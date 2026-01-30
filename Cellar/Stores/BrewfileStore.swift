import Foundation
import Observation

// MARK: - BrewfileStore

/// Manages Brewfile profile state: creation, deletion, export, import, and
/// content editing. Views bind to this store for the Brewfile management UI.
@Observable
@MainActor
final class BrewfileStore {

    // MARK: Data

    var profiles: [BrewfileProfile] = []

    // MARK: State

    var selectedProfileId: UUID?
    var brewfileContent: String = ""
    var isLoading = false
    var isImporting = false
    var errorMessage: String?
    var importStream: AsyncThrowingStream<String, Error>?

    // MARK: Computed

    var selectedProfile: BrewfileProfile? {
        guard let selectedProfileId else { return nil }
        return profiles.first { $0.id == selectedProfileId }
    }

    // MARK: Dependencies

    private let persistence = PersistenceService()
    private let service = BrewService()

    private static let fileName = "brewfile_profiles.json"

    // MARK: - Profile CRUD

    /// Loads saved profiles from disk.
    func loadProfiles() {
        profiles = persistence.loadOrDefault(
            [BrewfileProfile].self,
            from: Self.fileName,
            default: []
        )
        // If a profile was selected, reload its content
        if let profile = selectedProfile {
            loadBrewfileContent(for: profile)
        }
    }

    /// Persists current profiles to disk.
    func saveProfiles() {
        do {
            try persistence.save(profiles, to: Self.fileName)
        } catch {
            errorMessage = "Failed to save profiles: \(error.localizedDescription)"
        }
    }

    /// Creates a new profile and selects it.
    func createProfile(name: String, path: String) {
        let profile = BrewfileProfile(name: name, path: path)
        profiles.append(profile)
        selectedProfileId = profile.id
        brewfileContent = ""
        saveProfiles()
    }

    /// Deletes a profile. Clears the selection if the deleted profile was selected.
    func deleteProfile(_ profile: BrewfileProfile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileId == profile.id {
            selectedProfileId = nil
            brewfileContent = ""
        }
        saveProfiles()
    }

    // MARK: - Export

    /// Exports the current Homebrew state into the selected profile's Brewfile.
    func exportBrewfile(to profile: BrewfileProfile) async {
        isLoading = true
        errorMessage = nil
        do {
            try await service.bundleDump(to: profile.path)
            // Update last exported timestamp
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index].lastExported = Date()
                saveProfiles()
            }
            loadBrewfileContent(for: profile)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Import

    /// Returns a stream that installs packages from the profile's Brewfile.
    func importBrewfile(from profile: BrewfileProfile) -> AsyncThrowingStream<String, Error> {
        service.bundleInstall(from: profile.path)
    }

    /// Starts an import session, setting `importStream` for the view to consume.
    func beginImport(from profile: BrewfileProfile) {
        isImporting = true
        importStream = importBrewfile(from: profile)
    }

    /// Called when the import stream finishes.
    func endImport() {
        isImporting = false
        importStream = nil
    }

    // MARK: - Content

    /// Reads the Brewfile content from disk for display in the editor.
    func loadBrewfileContent(for profile: BrewfileProfile) {
        let url = URL(fileURLWithPath: profile.path)
        do {
            brewfileContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            brewfileContent = ""
        }
    }

    /// Saves the current editor content back to disk.
    func saveBrewfileContent(for profile: BrewfileProfile) {
        let url = URL(fileURLWithPath: profile.path)
        do {
            try brewfileContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Failed to save Brewfile: \(error.localizedDescription)"
        }
    }
}
