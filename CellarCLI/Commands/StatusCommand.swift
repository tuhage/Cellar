import Foundation
import CellarCore

enum StatusCommand {
    static func run() async throws {
        let service = BrewService()

        async let formulaeData = service.listFormulaeData()
        async let casksData = service.listCasksData()
        async let servicesData = service.listServicesData()

        let formulae = try await JSONDecoder().decode(BrewJSONResponse.self, from: formulaeData).formulae
        let casks = try await JSONDecoder().decode(BrewJSONResponse.self, from: casksData).casks ?? []
        let services = try await JSONDecoder().decode([BrewServiceItem].self, from: servicesData)

        let summary = SystemSummary.current(formulae: formulae, casks: casks, services: services)

        TerminalOutput.printHeader("Cellar Status")
        print("")

        printPackages(summary)
        printOutdated(summary)
        printServices(services)
    }

    // MARK: - Private

    private static func printPackages(_ summary: SystemSummary) {
        print("  \(TerminalOutput.bold("Packages"))")
        print("    Formulae:  \(summary.totalFormulae)")
        print("    Casks:     \(summary.totalCasks)")
        print("    Total:     \(summary.totalPackages)")
        print("")
    }

    private static func printOutdated(_ summary: SystemSummary) {
        if summary.updatesAvailable == 0 {
            print("  \(TerminalOutput.success("All packages up to date"))")
            print("")
            return
        }

        let label = summary.updatesAvailable == 1 ? "package" : "packages"
        print("  \(TerminalOutput.warning("\u{26A0} \(summary.updatesAvailable) outdated \(label)"))")

        for formula in summary.outdatedFormulae {
            print("    \(TerminalOutput.warning("\u{2191}")) \(formula.name) \(formula.version)")
        }
        for cask in summary.outdatedCasks {
            print("    \(TerminalOutput.warning("\u{2191}")) \(cask.token)")
        }

        print("")
    }

    private static func printServices(_ services: [BrewServiceItem]) {
        let running = services.filter(\.isRunning)
        let stopped = services.filter { !$0.isRunning }

        print("  \(TerminalOutput.bold("Services")) (\(running.count)/\(services.count) running)")

        for service in running {
            print("    \(TerminalOutput.statusDot(running: true)) \(service.name)")
        }
        for service in stopped {
            print("    \(TerminalOutput.statusDot(running: false)) \(TerminalOutput.colored(service.name, .dim))")
        }
    }
}
