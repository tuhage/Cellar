import CellarCore

enum RestartCommand {
    static func run(serviceName: String) async throws {
        let service = BrewService()

        print("Restarting \(serviceName)...")
        try await service.restartService(serviceName)
        TerminalOutput.printSuccess("\(serviceName) restarted")
    }
}
