import Foundation

public nonisolated final class BrewService: Sendable {
    public static let shared = BrewService()

    /// Internal so per-domain extensions in other files can run commands.
    let process: BrewProcessProtocol

    public init(process: BrewProcessProtocol = BrewProcess()) {
        self.process = process
    }

    // MARK: - Formula

    public func listFormulaeData() async throws -> Data {
        try await runJSON(["info", "--json=v2", "--installed", "--formula"])
    }

    public func formulaInfoData(_ name: String) async throws -> Data {
        try await runJSON(["info", "--json=v2", name])
    }

    // MARK: - Cask

    public func listCasksData() async throws -> Data {
        try await runJSON(["info", "--json=v2", "--installed", "--cask"])
    }

    public func caskInfoData(_ name: String) async throws -> Data {
        try await runJSON(["info", "--cask", "--json=v2", name])
    }

    // MARK: - Search

    public func searchFormulae(_ query: String) async throws -> [String] {
        let output = try await runChecked(["search", "--formula", query])
        return parseLines(output.stdout)
    }

    public func searchCasks(_ query: String) async throws -> [String] {
        let output = try await runChecked(["search", "--cask", query])
        return parseLines(output.stdout)
    }

    // MARK: - Install / Uninstall / Upgrade

    /// `--formula` / `--cask` is always explicit: without it brew resolves a
    /// bare name like `maestro` to a same-named cask instead of the formula.
    public func install(_ name: String, isCask: Bool = false) -> AsyncThrowingStream<String, Error> {
        process.stream(["install", isCask ? "--cask" : "--formula", name], includingStandardError: true)
    }

    public func uninstall(_ name: String, force: Bool = false) async throws {
        var args = ["uninstall"]
        if force { args.append("--ignore-dependencies") }
        args.append(name)
        try await runChecked(args)
    }

    public func upgrade(_ name: String, isCask: Bool = false) -> AsyncThrowingStream<String, Error> {
        process.stream(["upgrade", isCask ? "--cask" : "--formula", name], includingStandardError: true)
    }

    public func upgradeAll() -> AsyncThrowingStream<String, Error> {
        process.stream(["upgrade"])
    }

    /// What `brew upgrade` would do for the given packages, without doing it.
    public func upgradeDryRun(_ names: [String], isCask: Bool) async throws -> String {
        guard !names.isEmpty else { return "" }
        let output = try await runChecked(["upgrade", "--dry-run", isCask ? "--cask" : "--formula"] + names)
        return output.stdout
    }

    // MARK: - Update

    /// Refreshes Homebrew's package metadata. Every other command runs with
    /// auto-update disabled, so this is what makes "outdated" current.
    public func update() -> AsyncThrowingStream<String, Error> {
        process.stream(["update"], includingStandardError: true)
    }

    // MARK: - Services

    public func listServicesData() async throws -> Data {
        try await runJSON(["services", "list", "--json"])
    }

    public func startService(_ name: String, privileged: Bool = false) async throws {
        try await runChecked(["services", "start", name], privileged: privileged)
    }

    public func stopService(_ name: String, privileged: Bool = false) async throws {
        try await runChecked(["services", "stop", name], privileged: privileged)
    }

    public func restartService(_ name: String, privileged: Bool = false) async throws {
        try await runChecked(["services", "restart", name], privileged: privileged)
    }

    public func killService(_ name: String) async throws {
        try await runChecked(["services", "kill", name])
    }

    // MARK: - Taps

    public func listTapsData() async throws -> Data {
        try await runJSON(["tap-info", "--json", "--installed"])
    }

    public func addTap(_ name: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["tap", name])
    }

    public func removeTap(_ name: String) async throws {
        try await runChecked(["untap", name])
    }

    // MARK: - Generic Stream

    public func streamCommand(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        process.stream(arguments)
    }

    // MARK: - Health

    public func missing() async throws -> String {
        let output = try await process.run(["missing"])
        return output.stdout
    }

    // MARK: - Dependencies

    public func deps(_ name: String) async throws -> String {
        let output = try await runChecked(["deps", "--tree", name])
        return output.stdout
    }

    public func depsInstalled() async throws -> String {
        let output = try await runChecked(["deps", "--installed"])
        return output.stdout
    }

    public func uses(_ name: String) async throws -> [String] {
        let output = try await runChecked(["uses", "--installed", name])
        return parseLines(output.stdout)
    }

    // MARK: - Brewfile

    public func bundleDump(to path: String) async throws {
        try await runChecked(["bundle", "dump", "--file=\(path)", "--force"])
    }

    public func bundleInstall(from path: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["bundle", "install", "--file=\(path)"])
    }

    public func bundleCheck(at path: String) async throws -> String {
        let output = try await process.run(["bundle", "check", "--file=\(path)"])
        return output.stdout + output.stderr
    }

    public func bundleCleanup(at path: String) async throws -> String {
        let output = try await process.run(["bundle", "cleanup", "--file=\(path)"])
        return output.stdout
    }

    // MARK: - Pin

    public func pin(_ name: String) async throws {
        try await runChecked(["pin", name])
    }

    public func unpin(_ name: String) async throws {
        try await runChecked(["unpin", name])
    }

    // MARK: - Private

    /// Internal so per-domain extensions can run commands that must succeed.
    @discardableResult
    func runChecked(_ arguments: [String], privileged: Bool = false) async throws -> ProcessOutput {
        let output = privileged
            ? try await process.runPrivileged(arguments)
            : try await process.run(arguments)
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output
    }

    private func runJSON(_ arguments: [String]) async throws -> Data {
        let output = try await runChecked(arguments)
        guard let data = output.stdout.data(using: .utf8) else {
            throw BrewError.parsingFailure(context: "Invalid UTF-8 in brew output")
        }
        return data
    }

    private func parseLines(_ string: String) -> [String] {
        string.split(separator: "\n").map(String.init)
    }
}
