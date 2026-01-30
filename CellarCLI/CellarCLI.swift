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
                let name = try requireServiceName(from: arguments, command: "start")
                try await StartCommand.run(serviceName: name)
            case "stop":
                let name = try requireServiceName(from: arguments, command: "stop")
                try await StopCommand.run(serviceName: name)
            case "health":
                try await HealthCommand.run()
            case "cleanup":
                try await CleanupCommand.run()
            case "help", "--help", "-h":
                HelpCommand.run()
            case "version", "--version", "-v":
                print("cellar 1.0.0")
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

    private static func requireServiceName(
        from arguments: [String],
        command: String
    ) throws -> String {
        guard let name = arguments.dropFirst().first else {
            TerminalOutput.printError("Missing service name. Usage: cellar \(command) <service>")
            exit(1)
        }
        return name
    }
}
