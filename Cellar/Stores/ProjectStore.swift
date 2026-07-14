import Foundation
import Observation
import CellarCore

// MARK: - ProjectStore

/// Manages project environment state: creation, deletion, service activation,
/// and package tracking. Views bind to this store for the project management UI.
@Observable
@MainActor
final class ProjectStore: LoadableStore {

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

    // MARK: Activity

    var activityStore: ActivityStore?

    // MARK: Dependencies

    private let persistence = PersistenceService()
    private let service = BrewService.shared

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
        guard activityStore?.isActive(target: project.name) != true else { return }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .projectActivate(name: project.name))

        let previousProject = activeProject?.id == project.id ? nil : activeProject
        var stoppedPreviousServices: [String] = []
        var startedNewServices: [String] = []
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                if let previousProject {
                    for serviceName in previousProject.services {
                        try await self.service.stopService(serviceName)
                        stoppedPreviousServices.append(serviceName)
                    }
                }

                for serviceName in project.services {
                    try await self.service.startService(serviceName)
                    startedNewServices.append(serviceName)
                }
            }
            activeProjectId = project.id
            saveActiveId()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            // Restore the exact pre-activation state as far as possible.
            var rollbackFailures: [String] = []
            for serviceName in startedNewServices.reversed() {
                do { try await service.stopService(serviceName) }
                catch { rollbackFailures.append("stop \(serviceName)") }
            }
            for serviceName in stoppedPreviousServices {
                do { try await service.startService(serviceName) }
                catch { rollbackFailures.append("restart \(serviceName)") }
            }
            activeProjectId = previousProject?.id
            saveActiveId()

            let rollbackNote = rollbackFailures.isEmpty
                ? " Previous state was restored."
                : " Rollback also failed for: \(rollbackFailures.joined(separator: ", "))."
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) {
                errorMessage = "Failed to activate project: \(error.localizedDescription).\(rollbackNote)"
            }
        }
        isLoading = false
    }

    /// Deactivates the currently active project by stopping all its services.
    func deactivate() async {
        guard let project = activeProject else { return }
        isLoading = true
        errorMessage = nil
        let opID = activityStore?.register(kind: .projectDeactivate(name: project.name))

        var stoppedServices: [String] = []
        do {
            try await withCancellableActivity(activityStore, id: opID) {
                for serviceName in project.services {
                    try await self.service.stopService(serviceName)
                    stoppedServices.append(serviceName)
                }
            }
            activeProjectId = nil
            saveActiveId()
            if let opID { activityStore?.setStatus(opID, .succeeded) }
        } catch {
            var rollbackFailures: [String] = []
            for serviceName in stoppedServices {
                do { try await service.startService(serviceName) }
                catch { rollbackFailures.append(serviceName) }
            }
            let rollbackNote = rollbackFailures.isEmpty
                ? " Previous state was restored."
                : " Could not restart: \(rollbackFailures.joined(separator: ", "))."
            if let opID {
                activityStore?.setStatus(opID, isOperationCancellation(error)
                    ? .cancelled : .failed(reason: error.localizedDescription))
            }
            if !isOperationCancellation(error) {
                errorMessage = "Failed to deactivate project: \(error.localizedDescription).\(rollbackNote)"
            }
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
