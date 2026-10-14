import Testing
import Foundation
@testable import CellarCore

@Suite("Project activation")
struct ProjectActivationTests {

    private let web = Brewfile(kind: .project, name: "Web", path: "/p/web/Brewfile", services: ["postgresql@16", "redis"])
    private let api = Brewfile(kind: .project, name: "API", path: "/p/api/Brewfile", services: ["redis", "mysql"])

    @Test("activationPlan_startsOnlyStoppedServicesAndLeavesRunningOnesUnowned")
    func activationPlan_startsOnlyStoppedServicesAndLeavesRunningOnesUnowned() {
        let plan = ActivationPlan(activating: web, current: nil, currentProject: nil, running: ["redis"])

        #expect(plan.toStart == ["postgresql@16"])
        #expect(plan.alreadyRunning == ["redis"])
        #expect(plan.toStop.isEmpty)
        #expect(plan.activation.startedServices == ["postgresql@16"])
    }

    @Test("activationPlan_switching_stopsOnlyWhatThePreviousActivationStartedAndKeepsSharedServices")
    func activationPlan_switching_stopsOnlyWhatThePreviousActivationStartedAndKeepsSharedServices() {
        let current = ProjectActivation(brewfileID: web.id, startedServices: ["postgresql@16", "redis"])

        let plan = ActivationPlan(
            activating: api, current: current, currentProject: web,
            running: ["postgresql@16", "redis", "nginx"]
        )

        #expect(plan.toStop == ["postgresql@16"])
        #expect(plan.toStart == ["mysql"])
        #expect(plan.alreadyRunning.isEmpty)
        #expect(plan.previousProjectName == "Web")
        #expect(plan.activation.startedServices == ["redis", "mysql"])
    }

    @Test("activationPlan_reactivatingSameProject_restartsStoppedServicesWithoutStoppingAny")
    func activationPlan_reactivatingSameProject_restartsStoppedServicesWithoutStoppingAny() {
        let current = ProjectActivation(brewfileID: web.id, startedServices: ["postgresql@16", "redis"])

        let plan = ActivationPlan(activating: web, current: current, currentProject: web, running: ["redis"])

        #expect(plan.toStop.isEmpty)
        #expect(plan.toStart == ["postgresql@16"])
        #expect(plan.activation.startedServices == ["redis", "postgresql@16"])
    }

    @Test("projectActivation_servicesToStop_skipsServicesAlreadyStopped")
    func projectActivation_servicesToStop_skipsServicesAlreadyStopped() {
        let activation = ProjectActivation(brewfileID: web.id, startedServices: ["postgresql@16", "redis"])
        #expect(activation.servicesToStop(running: ["redis", "mysql"]) == ["redis"])
    }
}
