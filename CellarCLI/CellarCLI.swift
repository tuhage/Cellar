import Foundation
import CellarCore

@main
struct CellarCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = arguments.first else {
            HelpCommand.run()
            return
        }

        do {
            switch command {
            case "status":
                try await StatusCommand.run()
            case "start":
                let name = try requireArgument(from: arguments, for: "start")
                try await StartCommand.run(serviceName: name)
            case "stop":
                let name = try requireArgument(from: arguments, for: "stop")
                try await StopCommand.run(serviceName: name)
            case "restart":
                let name = try requireArgument(from: arguments, for: "restart")
                try await RestartCommand.run(serviceName: name)
            case "search":
                let query = try requireArgument(from: arguments, for: "search")
                try await SearchCommand.run(query: query)
            case "list":
                let filter = parseListFilter(from: arguments)
                try await ListCommand.run(filter: filter)
            case "health":
                try await HealthCommand.run()
            case "cleanup":
                try await CleanupCommand.run()
            case "help", "--help", "-h":
                HelpCommand.run()
            case "version", "--version", "-v":
                print("cellar \(AppVersion.current)")
            default:
                TerminalOutput.printError("Unknown command: \(command)")
                print("")
                HelpCommand.run()
                exit(1)
            }
        } catch {
            TerminalOutput.printError(error.localizedDescription)
            exit(1)
        }
    }

    private static func requireArgument(from arguments: [String], for command: String) throws -> String {
        guard let value = arguments.dropFirst().first else {
            throw CLIError.missingArgument(command: command)
        }
        return value
    }

    private static func parseListFilter(from arguments: [String]) -> ListCommand.Filter {
        let flags = Set(arguments.dropFirst())
        if flags.contains("--formulae") { return .formulae }
        if flags.contains("--casks") { return .casks }
        return .all
    }
}

enum CLIError: LocalizedError {
    case missingArgument(command: String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let command):
            let argument: String = switch command {
            case "search": "<query>"
            default: "<service>"
            }
            return "Missing argument. Usage: cellar \(command) \(argument)"
        }
    }
}
