import CellarCore

enum StartCommand {
    static func run(serviceName: String) async throws {
        let service = BrewService.shared

        print("Starting \(serviceName)...")
        try await service.startService(serviceName)
        TerminalOutput.printSuccess("\(serviceName) started")
    }
}
