import Foundation

/// Runs the macOS tools Cellar reads service state from (`ps`, `launchctl`,
/// `lsof`). They report "nothing found" through a non-zero exit, so callers
/// get `nil` rather than an error.
nonisolated enum SystemCommand {

    /// The tool's stdout, or `nil` when it failed or couldn't launch.
    static func output(_ path: String, _ arguments: [String]) async -> String? {
        guard let result = try? await BrewProcess.execute(
            executableURL: URL(fileURLWithPath: path),
            arguments: arguments,
            environment: nil
        ), result.exitCode == 0 else { return nil }
        return result.stdout
    }
}
