import Foundation
import CellarCore

enum CleanupCommand {
    static func run() async throws {
        TerminalOutput.printHeader("Homebrew Cleanup")
        print("")

        let service = BrewService()

        for try await line in service.cleanup() {
            print(line)
        }

        print("")
        TerminalOutput.printSuccess("Cleanup complete")
    }
}
