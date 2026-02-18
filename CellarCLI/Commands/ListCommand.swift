import Foundation
import CellarCore

enum ListCommand {
    enum Filter {
        case all
        case formulae
        case casks
    }

    static func run(filter: Filter) async throws {
        let service = BrewService()

        switch filter {
        case .all:
            async let formulaeData = service.listFormulaeData()
            async let casksData = service.listCasksData()

            let formulae = try await JSONDecoder().decode(BrewJSONResponse.self, from: formulaeData).formulae
            let casks = try await JSONDecoder().decode(BrewJSONResponse.self, from: casksData).casks ?? []

            printFormulae(formulae)
            printCasks(casks)

            let total = formulae.count + casks.count
            print(TerminalOutput.colored("\(total) packages installed", .dim))

        case .formulae:
            let data = try await service.listFormulaeData()
            let formulae = try JSONDecoder().decode(BrewJSONResponse.self, from: data).formulae

            printFormulae(formulae)
            print(TerminalOutput.colored("\(formulae.count) formulae installed", .dim))

        case .casks:
            let data = try await service.listCasksData()
            let casks = try JSONDecoder().decode(BrewJSONResponse.self, from: data).casks ?? []

            printCasks(casks)
            print(TerminalOutput.colored("\(casks.count) casks installed", .dim))
        }
    }

    // MARK: - Private

    private static func printFormulae(_ formulae: [Formula]) {
        guard !formulae.isEmpty else { return }

        TerminalOutput.printHeader("Formulae")
        for formula in formulae.sorted(by: { $0.name < $1.name }) {
            let version = formula.installedVersion ?? formula.version
            let outdated = formula.outdated ? " \(TerminalOutput.warning("(outdated)"))" : ""
            print("  \(formula.name) \(TerminalOutput.colored(version, .dim))\(outdated)")
        }
        print("")
    }

    private static func printCasks(_ casks: [Cask]) {
        guard !casks.isEmpty else { return }

        TerminalOutput.printHeader("Casks")
        for cask in casks.sorted(by: { $0.token < $1.token }) {
            let version = cask.installed ?? cask.version
            let outdated = cask.outdated ? " \(TerminalOutput.warning("(outdated)"))" : ""
            print("  \(cask.token) \(TerminalOutput.colored(version, .dim))\(outdated)")
        }
        print("")
    }
}
