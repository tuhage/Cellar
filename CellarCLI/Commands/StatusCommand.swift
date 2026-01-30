import Foundation
import CellarCore

enum StatusCommand {
    static func run() async throws {
        let service = BrewService()

        async let formulaeData = service.listFormulaeData()
        async let casksData = service.listCasksData()
        async let servicesData = service.listServicesData()

        let formulae = try await JSONDecoder.brew.decode(BrewJSONResponse.self, from: formulaeData).formulae
        let casks = try await JSONDecoder.brew.decode(BrewJSONResponse.self, from: casksData).casks ?? []
        let services = try await JSONDecoder().decode([BrewServiceItem].self, from: servicesData)

        let summary = SystemSummary.current(formulae: formulae, casks: casks, services: services)

        TerminalOutput.printHeader("Cellar Status")
        print("")

        printPackages(summary)
        printOutdated(summary)
        printServices(services)
    }

    private static func printPackages(_ summary: SystemSummary) {
        print("  \(TerminalOutput.bold("Packages"))")
        print("    Formulae:  \(summary.totalFormulae)")
        print("    Casks:     \(summary.totalCasks)")
        print("    Total:     \(summary.totalFormulae + summary.totalCasks)")
        print("")
    }

    private static func printOutdated(_ summary: SystemSummary) {
        let count = summary.updatesAvailable

        if count > 0 {
            let label = count == 1 ? "package" : "packages"
            print("  \(TerminalOutput.warning("\u{26A0} \(count) outdated \(label)"))")
            for formula in summary.outdatedFormulae {
                print("    \(TerminalOutput.warning("\u{2191}")) \(formula.name) \(formula.version)")
            }
            for cask in summary.outdatedCasks {
                print("    \(TerminalOutput.warning("\u{2191}")) \(cask.token)")
            }
        } else {
            print("  \(TerminalOutput.success("All packages up to date"))")
        }

        print("")
    }

    private static func printServices(_ services: [BrewServiceItem]) {
        let running = services.filter(\.isRunning)
        let stopped = services.filter { !$0.isRunning }

        print("  \(TerminalOutput.bold("Services")) (\(running.count)/\(services.count) running)")
        for svc in running {
            print("    \(TerminalOutput.statusDot(running: true)) \(svc.name)")
        }
        for svc in stopped {
            print("    \(TerminalOutput.statusDot(running: false)) \(TerminalOutput.colored(svc.name, .dim))")
        }
    }
}
