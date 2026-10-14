import Foundation

/// A directory brew reports with `brew --<name>`; each honours its
/// `HOMEBREW_*` override.
public enum BrewDirectory: String, Sendable, CaseIterable {
    case prefix, cellar, caskroom, cache
}

// MARK: - Maintenance

extension BrewService {

    // MARK: Cleanup

    /// What `brew cleanup` would remove. The parsed form is `CleanupPlan`.
    public func cleanupDryRun(_ depth: CleanupDepth = .standard) async throws -> String {
        try await runChecked(["cleanup", "--dry-run"] + depth.arguments).stdout
    }

    public func cleanup(_ depth: CleanupDepth = .standard) -> AsyncThrowingStream<String, Error> {
        process.stream(["cleanup"] + depth.arguments)
    }

    // MARK: Autoremove

    /// Which unused dependencies `brew autoremove` would uninstall.
    public func autoremoveDryRun() async throws -> String {
        try await runChecked(["autoremove", "--dry-run"]).stdout
    }

    public func autoremove() -> AsyncThrowingStream<String, Error> {
        process.stream(["autoremove"])
    }

    // MARK: Doctor

    /// `brew doctor`'s output. It exits non-zero whenever it finds issues,
    /// so the exit code is not an error; the parsed form is `DoctorReport`.
    public func doctor() async throws -> String {
        let output = try await process.run(["doctor"])
        return output.stdout + output.stderr
    }

    // MARK: Version

    /// "Homebrew 4.6.3" — the first line of `brew --version`.
    public func version() async throws -> String {
        let output = try await runChecked(["--version"]).stdout
        guard let line = output.split(whereSeparator: \.isNewline).first else {
            throw BrewError.parsingFailure(context: "Homebrew returned no version")
        }
        return String(line)
    }

    // MARK: Directories

    public func path(of directory: BrewDirectory) async throws -> String {
        let path = try await runChecked(["--\(directory.rawValue)"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw BrewError.parsingFailure(context: "Homebrew returned no \(directory.rawValue) path")
        }
        return path
    }
}
