import Foundation

// MARK: - Brewfile (`brew bundle`)

extension BrewService {

    /// Writes everything installed on this Mac into `path`, replacing the file.
    public func bundleDump(to path: String) async throws {
        try await runChecked(["bundle", "dump", "--file=\(path)", "--force"])
    }

    /// Installs what the Brewfile lists but isn't installed. Outdated
    /// packages are left alone; upgrading is a separate decision.
    public func bundleInstallMissing(from path: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["bundle", "install", "--no-upgrade", "--file=\(path)"], includingStandardError: true)
    }

    /// Which entries aren't installed. brew exits non-zero when something is
    /// missing, so only an `Error:` (such as an unreadable Brewfile) fails.
    public func bundleCheck(at path: String) async throws -> BrewfileCheck {
        let output = try await runReportingErrors(["bundle", "check", "--verbose", "--no-upgrade", "--file=\(path)"])
        return BrewfileCheck.parse(output.stdout + "\n" + output.stderr)
    }

    /// What `bundleCleanup(at:)` would remove — a dry run that changes nothing.
    public func bundleCleanupPlan(at path: String) async throws -> BrewfileCleanupPlan {
        let output = try await runReportingErrors(["bundle", "cleanup", "--file=\(path)"])
        return BrewfileCleanupPlan.parse(output.stdout)
    }

    /// Uninstalls everything the Brewfile doesn't list and runs `brew cleanup`.
    public func bundleCleanup(at path: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["bundle", "cleanup", "--force", "--file=\(path)"], includingStandardError: true)
    }

    // MARK: Private

    /// `brew bundle` exits non-zero to report findings, so only an `Error:`
    /// line means the command itself failed.
    private func runReportingErrors(_ arguments: [String]) async throws -> ProcessOutput {
        let output = try await process.run(arguments)
        if output.exitCode != 0, output.stderr.contains("Error:") {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output
    }
}
