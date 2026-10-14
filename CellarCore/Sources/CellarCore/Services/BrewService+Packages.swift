import Foundation

// MARK: - Packages

extension BrewService {

    /// `brew info` JSON for several packages at once. brew fails the whole
    /// call when one name is unknown.
    public func infoData(_ names: [String], isCask: Bool) async throws -> Data {
        try await runJSON(["info", "--json=v2", isCask ? "--cask" : "--formula"] + names)
    }

    public func reinstall(_ name: String, isCask: Bool) -> AsyncThrowingStream<String, Error> {
        process.stream(["reinstall", isCask ? "--cask" : "--formula", name], includingStandardError: true)
    }

    /// Upgrades a cask even when it updates itself, which `brew outdated`
    /// otherwise ignores.
    public func upgradeGreedy(cask token: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["upgrade", "--cask", "--greedy", token], includingStandardError: true)
    }

    /// `--formula` keeps a same-named cask from being removed instead.
    /// - Parameter ignoringDependents: Remove it even though installed
    ///   formulae still depend on it.
    public func uninstall(formula name: String, ignoringDependents: Bool = false) async throws {
        var arguments = ["uninstall", "--formula"]
        if ignoringDependents { arguments.append("--ignore-dependencies") }
        try await runChecked(arguments + [name])
    }

    /// - Parameters:
    ///   - force: Remove the cask even if brew thinks it isn't installed.
    ///   - zap: Also delete the app's settings, caches and support files.
    public func uninstall(cask token: String, force: Bool = false, zap: Bool = false) async throws {
        var arguments = ["uninstall", "--cask"]
        if force { arguments.append("--force") }
        if zap { arguments.append("--zap") }
        try await runChecked(arguments + [token])
    }
}
