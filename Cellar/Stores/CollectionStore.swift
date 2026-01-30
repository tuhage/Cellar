import Foundation
import Observation

// MARK: - CollectionStore

/// Manages package collection state: loading, creating, deleting collections,
/// and adding/removing packages. Merges user-created collections with built-in
/// ones on load.
@Observable
@MainActor
final class CollectionStore {

    // MARK: Data

    var collections: [PackageCollection] = []

    // MARK: State

    var selectedCollectionId: UUID?
    var isLoading = false
    var isInstalling = false
    var errorMessage: String?
    var installStream: AsyncThrowingStream<String, Error>?

    // MARK: Computed

    var selectedCollection: PackageCollection? {
        guard let selectedCollectionId else { return nil }
        return collections.first { $0.id == selectedCollectionId }
    }

    // MARK: Dependencies

    private let persistence = PersistenceService()
    private let service = BrewService()

    private static let fileName = "package_collections.json"

    // MARK: - Load & Save

    /// Loads user collections from persistence and merges with built-in collections.
    func load() {
        let savedCollections = persistence.loadOrDefault(
            [PackageCollection].self,
            from: Self.fileName,
            default: []
        )

        // Start with built-in collections, then add user-created ones
        var merged: [PackageCollection] = PackageCollection.builtInCollections
        for saved in savedCollections {
            // If a built-in was customized (same name), replace it
            if let index = merged.firstIndex(where: { $0.name == saved.name && $0.isBuiltIn && saved.isBuiltIn }) {
                merged[index] = saved
            } else if !saved.isBuiltIn {
                merged.append(saved)
            }
        }

        collections = merged
    }

    /// Persists all collections to disk.
    func save() {
        do {
            try persistence.save(collections, to: Self.fileName)
        } catch {
            errorMessage = "Failed to save collections: \(error.localizedDescription)"
        }
    }

    // MARK: - Collection CRUD

    /// Creates a new user collection and selects it.
    func create(name: String, icon: String, colorName: String) {
        let collection = PackageCollection(
            name: name,
            icon: icon,
            colorName: colorName,
            isBuiltIn: false
        )
        collections.append(collection)
        selectedCollectionId = collection.id
        save()
    }

    /// Deletes a collection. Only user-created collections can be deleted.
    func delete(_ collection: PackageCollection) {
        guard !collection.isBuiltIn else { return }
        collections.removeAll { $0.id == collection.id }
        if selectedCollectionId == collection.id {
            selectedCollectionId = nil
        }
        save()
    }

    // MARK: - Package Management

    /// Adds a formula name to the given collection's packages list.
    func addPackage(_ name: String, to collection: PackageCollection) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        guard !collections[index].packages.contains(name) else { return }
        collections[index].packages.append(name)
        save()
    }

    /// Removes a formula name from the given collection's packages list.
    func removePackage(_ name: String, from collection: PackageCollection) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        collections[index].packages.removeAll { $0 == name }
        save()
    }

    /// Adds a cask token to the given collection's casks list.
    func addCask(_ name: String, to collection: PackageCollection) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        guard !collections[index].casks.contains(name) else { return }
        collections[index].casks.append(name)
        save()
    }

    /// Removes a cask token from the given collection's casks list.
    func removeCask(_ name: String, from collection: PackageCollection) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        collections[index].casks.removeAll { $0 == name }
        save()
    }

    // MARK: - Bulk Install

    func installAll(_ collection: PackageCollection) {
        isInstalling = true
        errorMessage = nil

        let service = self.service
        let packages = collection.packages
        let casks = collection.casks

        installStream = AsyncThrowingStream { continuation in
            Task {
                do {
                    for name in packages {
                        continuation.yield("==> Installing formula: \(name)")
                        for try await line in service.install(name, isCask: false) {
                            continuation.yield(line)
                        }
                    }
                    for name in casks {
                        continuation.yield("==> Installing cask: \(name)")
                        for try await line in service.install(name, isCask: true) {
                            continuation.yield(line)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func endInstall() {
        isInstalling = false
        installStream = nil
    }
}
