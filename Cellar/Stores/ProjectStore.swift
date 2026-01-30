import Foundation
import Observation

// MARK: - ProjectStore

/// Manages project environment state: creation, deletion, service activation,
/// and package tracking. Views bind to this store for the project management UI.
@Observable
@MainActor
final class ProjectStore {

    // MARK: Data

    var projects: [ProjectEnvironment] = []

    // MARK: State

    var selectedProjectId: UUID?
    var activeProjectId: UUID?
    var isLoading = false
    var errorMessage: String?

    // MARK: Computed

    var selectedProject: ProjectEnvironment? {
        guard let selectedProjectId else { return nil }
        return projects.first { $0.id == selectedProjectId }
    }

    var activeProject: ProjectEnvironment? {
        guard let activeProjectId else { return nil }
        return projects.first { $0.id == activeProjectId }
    }

    // MARK: Dependencies

    private let persistence = PersistenceService()
    private let service = BrewService()

    private static let fileName = "project_environments.json"

    // MARK: - Load & Save

    /// Loads saved projects from persistence.
    func load() {
        projects = persistence.loadOrDefault(
            [ProjectEnvironment].self,
            from: Self.fileName,
            default: []
        )
        // Restore active project ID from a separate file
        activeProjectId = persistence.loadOrDefault(
            UUID?.self,
            from: "active_project_id.json",
            default: nil
        )
    }

    /// Persists current projects to disk.
    func save() {
        do {
            try persistence.save(projects, to: Self.fileName)
        } catch {
            errorMessage = "Failed to save projects: \(error.localizedDescription)"
        }
    }

    /// Persists the active project ID.
    private func saveActiveId() {
        do {
            try persistence.save(activeProjectId, to: "active_project_id.json")
        } catch {
            errorMessage = "Failed to save active project: \(error.localizedDescription)"
        }
    }

    // MARK: - Project CRUD

    /// Creates a new project and selects it.
    func create(name: String, path: String) {
        let project = ProjectEnvironment(name: name, path: path)
        projects.append(project)
        selectedProjectId = project.id
        save()
    }

    /// Deletes a project. Clears selection and active state if needed.
    func delete(_ project: ProjectEnvironment) {
        projects.removeAll { $0.id == project.id }
        if selectedProjectId == project.id {
            selectedProjectId = nil
        }
        if activeProjectId == project.id {
            activeProjectId = nil
            saveActiveId()
        }
        save()
    }

    // MARK: - Activate / Deactivate

    /// Activates a project by starting all its services.
    func activate(_ project: ProjectEnvironment) async {
        isLoading = true
        errorMessage = nil

        // If another project is active, deactivate it first
        if let currentActive = activeProject, currentActive.id != project.id {
            await deactivate()
        }

        do {
            for serviceName in project.services {
                try await service.startService(serviceName)
            }
            activeProjectId = project.id
            saveActiveId()
        } catch {
            errorMessage = "Failed to activate project: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Deactivates the currently active project by stopping all its services.
    func deactivate() async {
        guard let project = activeProject else { return }
        isLoading = true
        errorMessage = nil

        do {
            for serviceName in project.services {
                try await service.stopService(serviceName)
            }
            activeProjectId = nil
            saveActiveId()
        } catch {
            errorMessage = "Failed to deactivate project: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Service Management

    /// Adds a service to the given project.
    func addService(_ serviceName: String, to project: ProjectEnvironment) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard !projects[index].services.contains(serviceName) else { return }
        projects[index].services.append(serviceName)
        save()
    }

    /// Removes a service from the given project.
    func removeService(_ serviceName: String, from project: ProjectEnvironment) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].services.removeAll { $0 == serviceName }
        save()
    }

    // MARK: - Package Management

    /// Adds a package to the given project.
    func addPackage(_ packageName: String, to project: ProjectEnvironment) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard !projects[index].packages.contains(packageName) else { return }
        projects[index].packages.append(packageName)
        save()
    }

    /// Removes a package from the given project.
    func removePackage(_ packageName: String, from project: ProjectEnvironment) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].packages.removeAll { $0 == packageName }
        save()
    }

    // MARK: - Missing Packages

    /// Checks which of the project's required packages are not currently installed.
    func checkMissingPackages(_ project: ProjectEnvironment) async -> [String] {
        do {
            let installedFormulae = try await Formula.all
            let installedNames = Set(installedFormulae.map(\.name))
            return project.packages.filter { !installedNames.contains($0) }
        } catch {
            errorMessage = "Failed to check packages: \(error.localizedDescription)"
            return []
        }
    }
}
