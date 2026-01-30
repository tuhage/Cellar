import Foundation
import CellarCore

enum StatusCommand {
    static func run() async throws {
        let service = BrewService()

        let formulaeData = try await service.listFormulaeData()
        let casksData = try await service.listCasksData()
        let servicesData = try await service.listServicesData()

        let formulae = try JSONDecoder.brew.decode(BrewJSONResponse.self, from: formulaeData).formulae
        let casks = try JSONDecoder.brew.decode(BrewJSONResponse.self, from: casksData).casks ?? []
        let services = try JSONDecoder().decode([BrewServiceItem].self, from: servicesData)

        let summary = SystemSummary.current(formulae: formulae, casks: casks, services: services)

        TerminalOutput.printHeader("Cellar Status")
        print("")

        // Packages
        print("  \(TerminalOutput.bold("Packages"))")
        print("    Formulae:  \(summary.totalFormulae)")
        print("    Casks:     \(summary.totalCasks)")
        print("    Total:     \(summary.totalFormulae + summary.totalCasks)")
        print("")

        // Outdated
        let outdatedCount = summary.updatesAvailable
        if outdatedCount > 0 {
            print("  \(TerminalOutput.warning("⚠ \(outdatedCount) outdated package\(outdatedCount == 1 ? "" : "s")"))")
            for formula in summary.outdatedFormulae {
                print("    \(TerminalOutput.warning("↑")) \(formula.name) \(formula.version)")
            }
            for cask in summary.outdatedCasks {
                print("    \(TerminalOutput.warning("↑")) \(cask.token)")
            }
        } else {
            print("  \(TerminalOutput.success("All packages up to date"))")
        }
        print("")

        // Services
        let running = services.filter(\.isRunning)
        let stopped = services.filter { !$0.isRunning }

        print("  \(TerminalOutput.bold("Services")) (\(running.count)/\(services.count) running)")
        for svc in running {
            print("    \(TerminalOutput.printStatusDot(running: true)) \(svc.name)")
        }
        for svc in stopped {
            print("    \(TerminalOutput.printStatusDot(running: false)) \(TerminalOutput.colored(svc.name, .dim))")
        }
    }
}
