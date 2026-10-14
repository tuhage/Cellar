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
    var lastUpdated: Date?

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

    let activityStore: ActivityStore
    private let persistence = PersistenceService()
    private let service = BrewService.shared

    init(activityStore: ActivityStore) {
        self.activityStore = activityStore
    }

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

    /// Activates a project by starting its services, after stopping the
    /// previously active project's ones. Rolls back on failure.
    func activate(_ project: ProjectEnvironment) async {
        let previousProject = activeProject?.id == project.id ? nil : activeProject
        await activityStore.perform(.projectActivate(name: project.name)) { activity in
            var stopped: [String] = []
            var started: [String] = []
            do {
                for name in previousProject?.services ?? [] {
                    try await self.service.stopService(name)
                    stopped.append(name)
                }
                for name in project.services {
                    try await self.service.startService(name)
                    started.append(name)
                }
            } catch {
                await self.rollBack(starting: stopped, stopping: started, in: activity)
                throw error
            }
            self.setActiveProject(project.id)
        }
    }

    /// Deactivates the active project by stopping its services. Rolls back
    /// on failure.
    func deactivate() async {
        guard let project = activeProject else { return }
        await activityStore.perform(.projectDeactivate(name: project.name)) { activity in
            var stopped: [String] = []
            do {
                for name in project.services {
                    try await self.service.stopService(name)
                    stopped.append(name)
                }
            } catch {
                await self.rollBack(starting: stopped, stopping: [], in: activity)
                throw error
            }
            self.setActiveProject(nil)
        }
    }

    /// Best-effort restore of the services touched before a failure.
    private func rollBack(starting toStart: [String], stopping toStop: [String], in activity: ActivityContext) async {
        for name in toStop.reversed() {
            do { try await service.stopService(name) } catch { activity.log("Rollback couldn’t stop \(name)") }
        }
        for name in toStart {
            do { try await service.startService(name) } catch { activity.log("Rollback couldn’t start \(name)") }
        }
    }

    private func setActiveProject(_ id: UUID?) {
        activeProjectId = id
        saveActiveId()
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
