import Foundation

public nonisolated final class BrewService: Sendable {
    private let process: BrewProcessProtocol

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

    public func install(_ name: String, isCask: Bool = false) -> AsyncThrowingStream<String, Error> {
        var args = ["install"]
        if isCask { args.append("--cask") }
        args.append(name)
        return process.stream(args)
    }

    public func uninstall(_ name: String) async throws {
        try await runChecked(["uninstall", name])
    }

    public func upgrade(_ name: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["upgrade", name])
    }

    public func upgradeAll() -> AsyncThrowingStream<String, Error> {
        process.stream(["upgrade"])
    }

    // MARK: - Cleanup

    public func cleanupDryRun() async throws -> String {
        let output = try await runChecked(["cleanup", "-n"])
        return output.stdout
    }

    public func cleanup() -> AsyncThrowingStream<String, Error> {
        process.stream(["cleanup"])
    }

    public func cleanupAggressive() -> AsyncThrowingStream<String, Error> {
        process.stream(["cleanup", "--prune=all", "-s"])
    }

    // MARK: - Services

    public func listServicesData() async throws -> Data {
        try await runJSON(["services", "list", "--json"])
    }

    public func startService(_ name: String) async throws {
        try await runChecked(["services", "start", name])
    }

    public func stopService(_ name: String) async throws {
        try await runChecked(["services", "stop", name])
    }

    public func restartService(_ name: String) async throws {
        try await runChecked(["services", "restart", name])
    }

    // MARK: - Generic Stream

    public func streamCommand(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        process.stream(arguments)
    }

    // MARK: - Health

    public func doctor() async throws -> String {
        let output = try await process.run(["doctor"])
        // brew doctor exits non-zero when issues found -- that's expected
        return output.stdout + output.stderr
    }

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

    @discardableResult
    private func runChecked(_ arguments: [String]) async throws -> ProcessOutput {
        let output = try await process.run(arguments)
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
