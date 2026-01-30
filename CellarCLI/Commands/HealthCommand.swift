import Foundation
import CellarCore

enum HealthCommand {
    static func run() async throws {
        TerminalOutput.printHeader("Homebrew Health Check")
        print("")

        let service = BrewService()

        print("Running \(TerminalOutput.info("brew doctor"))...")
        print("")

        let output = try await service.doctor()

        if output.contains("Your system is ready to brew") {
            TerminalOutput.printSuccess("Your system is ready to brew.")
        } else {
            let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
            for line in lines {
                let text = String(line)
                if text.hasPrefix("Warning:") || text.hasPrefix("Error:") {
                    print(TerminalOutput.warning(text))
                } else {
                    print(text)
                }
            }
        }
    }
}
