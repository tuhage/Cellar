#if DEBUG
import Foundation
import CellarCore

/// Sample operations for SwiftUI previews.
extension BrewOperation {

    static var upgradeAllPreview: BrewOperation {
        var steps = [
            Step(name: "docker", isCask: false, currentVersion: "29.8.0", targetVersion: "29.9.0"),
            Step(name: "maestro", isCask: false, currentVersion: "2.10.0", targetVersion: "2.11.0"),
            Step(name: "gradle", isCask: false, currentVersion: "9.7.0", targetVersion: "9.8.1"),
            Step(name: "openjdk@17", isCask: false, currentVersion: "17.0.20", targetVersion: "17.0.20.1"),
            Step(name: "tailscale", isCask: false, currentVersion: "1.102.2", targetVersion: "1.104.1"),
        ]
        steps[0].status = .succeeded
        steps[1].status = .failed(Failure(
            reason: "Your Command Line Tools are too outdated.",
            issue: .outdatedCommandLineTools
        ))
        steps[2].status = .running
        steps[2].startedAt = Date().addingTimeInterval(-42)
        return BrewOperation(
            kind: .upgradeAll(count: steps.count),
            log: ["==> Upgrading gradle", "==> Pouring gradle--9.8.1.all.bottle.tar.gz"],
            lastOutputAt: Date().addingTimeInterval(-5),
            steps: steps
        )
    }

    /// A running, a succeeded and a failed operation.
    static var previewList: [BrewOperation] {
        [
            upgradeAllPreview,
            BrewOperation(
                kind: .install(name: "wget", isCask: false),
                status: .succeeded,
                completedAt: Date(),
                log: ["==> Pouring wget--1.25.0.arm64_tahoe.bottle.tar.gz"]
            ),
            BrewOperation(
                kind: .uninstall(name: "openssl@3", isCask: false),
                status: .failed(Failure(reason: "Refusing to uninstall openssl@3 because it is required by curl")),
                completedAt: Date()
            ),
        ]
    }
}
#endif
