import Foundation

// MARK: - ProjectActivation

/// The project whose services Cellar started, and which ones it started.
///
/// Deactivating stops only `startedServices`, so services that were already
/// running before activation keep running.
public struct ProjectActivation: Codable, Hashable, Sendable {
    public let brewfileID: UUID
    public var startedServices: [String]

    public init(brewfileID: UUID, startedServices: [String]) {
        self.brewfileID = brewfileID
        self.startedServices = startedServices
    }

    /// The services Deactivate stops: the ones this activation started that
    /// are still running.
    public func servicesToStop(running: Set<String>) -> [String] {
        startedServices.filter(running.contains)
    }
}

// MARK: - ActivationPlan

/// What activating a project will do, shown before anything happens.
public struct ActivationPlan: Equatable, Sendable {
    public let projectID: UUID
    /// Project services that aren't running yet.
    public let toStart: [String]
    /// Project services already running on their own; Deactivate leaves them.
    public let alreadyRunning: [String]
    /// Services the previously active project started that this one doesn't use.
    public let toStop: [String]
    public let previousProjectName: String?
    /// Services the new activation owns: started now, or started by the
    /// previous activation and shared with this project.
    public let startedServices: [String]

    public var activation: ProjectActivation {
        ProjectActivation(brewfileID: projectID, startedServices: startedServices)
    }

    public var changesNothing: Bool { toStart.isEmpty && toStop.isEmpty }

    /// - Parameters:
    ///   - current: The activation in effect, possibly of another project.
    ///   - currentProject: The project `current` belongs to, for its name.
    ///   - running: Names of the services running right now.
    public init(
        activating project: Brewfile,
        current: ProjectActivation?,
        currentProject: Brewfile?,
        running: Set<String>
    ) {
        let needed = Set(project.services)
        let ownedBefore = current?.servicesToStop(running: running) ?? []
        let isSwitching = current.map { $0.brewfileID != project.id } ?? false
        let inherited = ownedBefore.filter(needed.contains)

        projectID = project.id
        toStart = project.services.filter { !running.contains($0) }
        alreadyRunning = project.services.filter { running.contains($0) && !inherited.contains($0) }
        toStop = isSwitching ? ownedBefore.filter { !needed.contains($0) } : []
        previousProjectName = isSwitching && !toStop.isEmpty ? currentProject?.name : nil
        startedServices = inherited + toStart
    }
}
