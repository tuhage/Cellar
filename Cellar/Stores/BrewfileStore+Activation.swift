import Foundation
import CellarCore

// MARK: - Project Activation

/// How far a project's services are running right now, read from the live
/// service list rather than from what Cellar last did.
enum ProjectServiceState: Equatable {
    case noServices
    case running
    case partial(running: Int, total: Int)
    case stopped
}

extension BrewfileStore {

    var runningServiceNames: Set<String> {
        Set(services.runningServices.map(\.name))
    }

    /// The project Cellar activated, if it is still in the list.
    var activeProject: Brewfile? {
        library.activation.flatMap { brewfile(withID: $0.brewfileID) }
    }

    func isActivated(_ project: Brewfile) -> Bool {
        library.activation?.brewfileID == project.id
    }

    func serviceState(of project: Brewfile) -> ProjectServiceState {
        guard !project.services.isEmpty else { return .noServices }
        let running = project.services.count(where: runningServiceNames.contains)
        if running == project.services.count { return .running }
        return running == 0 ? .stopped : .partial(running: running, total: project.services.count)
    }

    /// What activating `project` would start and stop, for the preview.
    func activationPlan(for project: Brewfile) -> ActivationPlan {
        ActivationPlan(
            activating: project,
            current: library.activation,
            currentProject: activeProject,
            running: runningServiceNames
        )
    }

    /// The services Deactivate would stop.
    func servicesToStopOnDeactivation(of project: Brewfile) -> [String] {
        guard isActivated(project), let activation = library.activation else { return [] }
        return activation.servicesToStop(running: runningServiceNames)
    }

    /// Carries out `plan`: stops what the previous project started and no
    /// longer needed, then starts this project's stopped services. With
    /// `registerAtLogin` off, services run for this session only
    /// (`brew services run`). Rolls back if a step fails.
    func activate(_ project: Brewfile, plan: ActivationPlan, registerAtLogin: Bool) async {
        await activityStore.perform(.projectActivate(name: project.name)) { activity in
            var stopped: [String] = []
            var started: [String] = []
            do {
                for name in plan.toStop {
                    try await self.stopService(name, in: activity)
                    stopped.append(name)
                }
                for name in plan.toStart {
                    try await self.startService(name, registerAtLogin: registerAtLogin, in: activity)
                    started.append(name)
                }
            } catch {
                await self.rollBack(starting: stopped, stopping: started, in: activity)
                throw error
            }
            self.library.activation = plan.activation
            self.save()
        }
        await services.load(forceRefresh: true)
    }

    /// Stops only the services activation started; ones that were already
    /// running keep running.
    func deactivate(_ project: Brewfile) async {
        let toStop = servicesToStopOnDeactivation(of: project)
        await activityStore.perform(.projectDeactivate(name: project.name)) { activity in
            var stopped: [String] = []
            do {
                for name in toStop {
                    try await self.stopService(name, in: activity)
                    stopped.append(name)
                }
            } catch {
                await self.rollBack(starting: stopped, stopping: [], in: activity)
                throw error
            }
            self.library.activation = nil
            self.save()
        }
        await services.load(forceRefresh: true)
    }

    // MARK: Private

    /// Services registered under `root` need an admin prompt.
    private func requiresRoot(_ name: String) -> Bool {
        services.services.first { $0.name == name }?.requiresRoot ?? false
    }

    private func startService(_ name: String, registerAtLogin: Bool, in activity: ActivityContext) async throws {
        activity.log(registerAtLogin ? "Starting \(name)" : "Running \(name) for this session")
        if registerAtLogin {
            try await brew.startService(name, privileged: requiresRoot(name))
        } else {
            try await brew.runService(name, privileged: requiresRoot(name))
        }
    }

    private func stopService(_ name: String, in activity: ActivityContext) async throws {
        activity.log("Stopping \(name)")
        try await brew.stopService(name, privileged: requiresRoot(name))
    }

    /// Best-effort restore of the services touched before a failure.
    private func rollBack(starting toStart: [String], stopping toStop: [String], in activity: ActivityContext) async {
        for name in toStop.reversed() {
            do { try await stopService(name, in: activity) } catch { activity.log("Rollback couldn’t stop \(name)") }
        }
        for name in toStart {
            do { try await startService(name, registerAtLogin: false, in: activity) } catch {
                activity.log("Rollback couldn’t start \(name)")
            }
        }
    }
}
