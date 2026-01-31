import Foundation
import Observation
import CellarCore

// MARK: - BrewfileCreationMode

enum BrewfileCreationMode: String, CaseIterable, Identifiable {
    case empty = "Empty Brewfile"
    case generate = "Generate from System"

    var id: String { rawValue }
}

// MARK: - BrewfileStore

/// Manages Brewfile profile state: creation, deletion, export, import,
/// check, cleanup, and content editing. Views bind to this store for
/// the Brewfile management UI.
@Observable
@MainActor
final class BrewfileStore {

    // MARK: Data

    var profiles: [BrewfileProfile] = []
    var parsedContent: BrewfileContent = .empty

    // MARK: State

    var selectedProfileId: UUID?
    var brewfileContent: String = ""
    var isLoading = false
    var errorMessage: String?

    // Action stream (shared for install / cleanup output)
    var actionStream: AsyncThrowingStream<String, Error>?
    var actionTitle: String?

    // Check result
    var checkResult: String?
    var isChecking = false

    // MARK: Computed

    var selectedProfile: BrewfileProfile? {
        guard let selectedProfileId else { return nil }
        return profiles.first { $0.id == selectedProfileId }
    }

    var isPerformingAction: Bool { actionStream != nil }

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
        parsedContent = .empty
        saveProfiles()
    }

    /// Deletes a profile. Clears the selection if the deleted profile was selected.
    func deleteProfile(_ profile: BrewfileProfile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileId == profile.id {
            selectedProfileId = nil
            brewfileContent = ""
            parsedContent = .empty
            checkResult = nil
        }
        saveProfiles()
    }

    /// Selects a profile by ID and loads its content.
    func selectProfile(_ id: UUID?) {
        selectedProfileId = id
        checkResult = nil
        if let id, let profile = profiles.first(where: { $0.id == id }) {
            loadBrewfileContent(for: profile)
        } else {
            brewfileContent = ""
            parsedContent = .empty
        }
    }

    /// Creates a default profile if none exist yet.
    func ensureDefaultProfile() {
        guard profiles.isEmpty else { return }
        createProfile(name: "Default", path: "\(NSHomeDirectory())/Brewfile")
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

    // MARK: - Check

    /// Runs `brew bundle check` against the given profile's Brewfile.
    func checkBrewfile(for profile: BrewfileProfile) async {
        isChecking = true
        checkResult = nil
        errorMessage = nil
        do {
            let output = try await service.bundleCheck(at: profile.path)
            checkResult = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            checkResult = "Check failed: \(error.localizedDescription)"
        }
        isChecking = false
    }

    // MARK: - Cleanup

    /// Runs `brew bundle cleanup` to remove packages not listed in the Brewfile.
    func cleanupBrewfile(for profile: BrewfileProfile) {
        actionTitle = "Brewfile Cleanup"
        actionStream = AsyncThrowingStream { continuation in
            Task {
                do {
                    let output = try await self.service.bundleCleanup(at: profile.path)
                    let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.yield(message.isEmpty ? "Nothing to clean up." : message)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Starts a streaming install session via the action stream.
    func beginInstall(from profile: BrewfileProfile) {
        actionTitle = "Installing from Brewfile"
        actionStream = AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in self.service.bundleInstall(from: profile.path) {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Dismisses the current action stream.
    func dismissAction() {
        actionStream = nil
        actionTitle = nil
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
        parsedContent = BrewfileContent.parse(from: brewfileContent)
    }

    /// Saves the current editor content back to disk.
    func saveBrewfileContent(for profile: BrewfileProfile) {
        let url = URL(fileURLWithPath: profile.path)
        do {
            try brewfileContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Failed to save Brewfile: \(error.localizedDescription)"
        }
        parsedContent = BrewfileContent.parse(from: brewfileContent)
    }
}
