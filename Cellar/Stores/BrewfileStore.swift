import Foundation
import Observation
import CellarCore

// MARK: - BrewfileCreationMode

enum BrewfileCreationMode: String, CaseIterable, Identifiable {
    case empty = "Empty Brewfile"
    case generate = "Generate from System"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .empty: "Empty"
        case .generate: "Generate from system"
        }
    }

    var subtitle: String {
        switch self {
        case .empty: "Start with an empty Brewfile."
        case .generate: "Export currently installed packages."
        }
    }
}

// MARK: - BrewfileStore

/// Manages Brewfile profile state: creation, deletion, export, import,
/// check, cleanup, and content editing. Views bind to this store for
/// the Brewfile management UI.
@Observable
@MainActor
final class BrewfileStore: LoadableStore {

    // MARK: Data

    var profiles: [BrewfileProfile] = []
    var parsedContent: BrewfileContent = .empty

    // MARK: State

    var selectedProfileId: UUID?
    var brewfileContent: String = ""
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    // Check result
    var checkResult: String?
    var isChecking = false

    // MARK: Computed

    var selectedProfile: BrewfileProfile? {
        guard let selectedProfileId else { return nil }
        return profiles.first { $0.id == selectedProfileId }
    }

    /// The install, export or cleanup running for the selected profile.
    var runningOperation: BrewOperation? {
        selectedProfile.flatMap { activityStore.runningOperation(for: .brewfile($0.name)) }
    }

    var isPerformingAction: Bool { runningOperation != nil }

    var brewfileExistsOnDisk: Bool {
        guard let profile = selectedProfile else { return false }
        return FileManager.default.fileExists(atPath: profile.path)
    }

    // MARK: Dependencies

    let activityStore: ActivityStore
    private let persistence = PersistenceService()
    private let service = BrewService.shared

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
    }

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
    func createProfile(name: String, path: String, mode: BrewfileCreationMode = .empty) {
        let profile = BrewfileProfile(name: name, path: path)
        profiles.append(profile)
        selectedProfileId = profile.id
        resetContent()
        saveProfiles()

        switch mode {
        case .empty:
            createEmptyBrewfileIfMissing(at: path)
            loadBrewfileContent(for: profile)
        case .generate:
            Task { await exportBrewfile(to: profile) }
        }
    }

    /// Deletes a profile. Clears the selection if the deleted profile was selected.
    func deleteProfile(_ profile: BrewfileProfile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileId == profile.id {
            selectedProfileId = nil
            resetContent()
        }
        saveProfiles()
    }

    /// Deletes the Brewfile from disk without removing the profile metadata.
    func deleteBrewfile(for profile: BrewfileProfile) {
        do {
            try FileManager.default.removeItem(atPath: profile.path)
            resetContent()
        } catch {
            errorMessage = "Failed to delete Brewfile: \(error.localizedDescription)"
        }
    }

    /// Selects a profile by ID and loads its content.
    func selectProfile(_ id: UUID?) {
        selectedProfileId = id
        checkResult = nil
        if let id, let profile = profiles.first(where: { $0.id == id }) {
            loadBrewfileContent(for: profile)
        } else {
            resetContent()
        }
    }

    /// Creates a default profile if none exist yet. An existing `~/Brewfile`
    /// is adopted as is, never overwritten.
    func ensureDefaultProfile() {
        guard profiles.isEmpty else { return }
        createProfile(name: "Default", path: "\(NSHomeDirectory())/Brewfile")
    }

    /// Writes a commented header to a new Brewfile. Leaves existing files alone.
    private func createEmptyBrewfileIfMissing(at path: String) {
        guard !FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let header = "# Brewfile\n# Created \(Date().formatted(date: .abbreviated, time: .omitted))\n"
            try header.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Failed to create Brewfile: \(error.localizedDescription)"
        }
    }

    // MARK: - Export

    /// Writes the currently installed packages into the profile's Brewfile.
    func exportBrewfile(to profile: BrewfileProfile) async {
        await activityStore.perform(.brewfileExport(name: profile.name)) { _ in
            try await self.service.bundleDump(to: profile.path)
            if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                self.profiles[index].lastExported = Date()
                self.saveProfiles()
            }
            self.loadBrewfileContent(for: profile)
        }
    }

    // MARK: - Check

    /// Runs `brew bundle check` against the given profile's Brewfile.
    func checkBrewfile(for profile: BrewfileProfile) async {
        isChecking = true
        checkResult = nil
        do {
            let output = try await service.bundleCheck(at: profile.path)
            checkResult = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            checkResult = "Check failed: \(error.briefDescription)"
        }
        isChecking = false
    }

    // MARK: - Install & Cleanup

    /// Runs `brew bundle cleanup` for the profile's Brewfile.
    func cleanupBrewfile(for profile: BrewfileProfile) async {
        await activityStore.perform(.brewfileCleanup(name: profile.name)) { activity in
            let output = try await self.service.bundleCleanup(at: profile.path)
            activity.log(output: output.isEmpty ? "Nothing to clean up." : output)
        }
    }

    /// Runs `brew bundle install` for the profile's Brewfile.
    func install(from profile: BrewfileProfile) async {
        await activityStore.perform(.brewfileInstall(name: profile.name)) { activity in
            try await activity.stream(self.service.bundleInstall(from: profile.path))
        }
    }

    // MARK: - Content

    /// Resets all content state to empty.
    private func resetContent() {
        brewfileContent = ""
        parsedContent = .empty
        checkResult = nil
    }

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
