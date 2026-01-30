import Foundation
import CellarCore

enum StopCommand {
    static func run(serviceName: String) async throws {
        let service = BrewService()

        print("Stopping \(serviceName)...")
        try await service.stopService(serviceName)
        TerminalOutput.printSuccess("\(serviceName) stopped")
    }
}
