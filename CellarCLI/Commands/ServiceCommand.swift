import CellarCore

/// `cellar start|stop|restart <service>`. Goes through `BrewServiceItem`,
/// so services registered under root ask for an administrator password.
enum ServiceCommand {
    enum Action {
        case start, stop, restart

        fileprivate var progressTitle: String {
            switch self {
            case .start: "Starting"
            case .stop: "Stopping"
            case .restart: "Restarting"
            }
        }

        fileprivate var doneTitle: String {
            switch self {
            case .start: "started"
            case .stop: "stopped"
            case .restart: "restarted"
            }
        }
    }

    static func run(_ action: Action, serviceName: String) async throws {
        guard let service = try await BrewServiceItem.all.first(where: { $0.name == serviceName }) else {
            throw CLIError.unknownService(serviceName)
        }
        print("\(action.progressTitle) \(serviceName)...")
        switch action {
        case .start: try await service.start()
        case .stop: try await service.stop()
        case .restart: try await service.restart()
        }
        TerminalOutput.printSuccess("\(serviceName) \(action.doneTitle)")
    }
}
