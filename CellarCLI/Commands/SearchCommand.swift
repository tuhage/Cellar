import CellarCore

enum SearchCommand {
    static func run(query: String) async throws {
        let service = BrewService()

        async let formulaeNames = service.searchFormulae(query)
        async let caskNames = service.searchCasks(query)

        let formulae = try await formulaeNames
        let casks = try await caskNames

        if formulae.isEmpty && casks.isEmpty {
            print(TerminalOutput.warning("No results found for \"\(query)\""))
            return
        }

        if !formulae.isEmpty {
            TerminalOutput.printHeader("Formulae")
            for name in formulae {
                print("  \(name)")
            }
            print("")
        }

        if !casks.isEmpty {
            TerminalOutput.printHeader("Casks")
            for name in casks {
                print("  \(name)")
            }
            print("")
        }

        let total = formulae.count + casks.count
        let label = total == 1 ? "result" : "results"
        print(TerminalOutput.colored("\(total) \(label) found", .dim))
    }
}
