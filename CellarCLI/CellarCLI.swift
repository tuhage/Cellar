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
                guard let serviceName = arguments.dropFirst().first else {
                    TerminalOutput.printError("Missing service name. Usage: cellar start <service>")
                    exit(1)
                }
                try await StartCommand.run(serviceName: serviceName)
            case "stop":
                guard let serviceName = arguments.dropFirst().first else {
                    TerminalOutput.printError("Missing service name. Usage: cellar stop <service>")
                    exit(1)
                }
                try await StopCommand.run(serviceName: serviceName)
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
}
