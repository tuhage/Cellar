import Foundation

nonisolated final class BrewService: Sendable {
    private let process: BrewProcessProtocol

    init(process: BrewProcessProtocol = BrewProcess()) {
        self.process = process
    }

    // MARK: - Formula

    func listFormulae() async throws -> [[String: Any]] {
        let output = try await process.run(["list", "--formula", "--json=v2"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return try parseJSONv2(output.stdout, key: "formulae")
    }

    func formulaInfo(_ name: String) async throws -> [String: Any] {
        let output = try await process.run(["info", "--json=v2", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        let items: [[String: Any]] = try parseJSONv2(output.stdout, key: "formulae")
        guard let first = items.first else {
            throw BrewError.parsingFailure(context: "No formula info for \(name)")
        }
        return first
    }

    // MARK: - Cask

    func listCasks() async throws -> [[String: Any]] {
        let output = try await process.run(["list", "--cask", "--json=v2"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return try parseJSONv2(output.stdout, key: "casks")
    }

    func caskInfo(_ name: String) async throws -> [String: Any] {
        let output = try await process.run(["info", "--cask", "--json=v2", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        let items: [[String: Any]] = try parseJSONv2(output.stdout, key: "casks")
        guard let first = items.first else {
            throw BrewError.parsingFailure(context: "No cask info for \(name)")
        }
        return first
    }

    // MARK: - Search

    func searchFormulae(_ query: String) async throws -> [String] {
        let output = try await process.run(["search", "--formula", query])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output.stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    func searchCasks(_ query: String) async throws -> [String] {
        let output = try await process.run(["search", "--cask", query])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output.stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: - Outdated

    func outdated() async throws -> [[String: Any]] {
        let output = try await process.run(["outdated", "--json=v2"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        guard let data = output.stdout.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrewError.parsingFailure(context: "Invalid outdated JSON")
        }
        let formulae = json["formulae"] as? [[String: Any]] ?? []
        let casks = json["casks"] as? [[String: Any]] ?? []
        return formulae + casks
    }

    // MARK: - Install / Uninstall / Upgrade

    func install(_ name: String, isCask: Bool = false) -> AsyncThrowingStream<String, Error> {
        var args = ["install"]
        if isCask { args.append("--cask") }
        args.append(name)
        return process.stream(args)
    }

    func uninstall(_ name: String) async throws {
        let output = try await process.run(["uninstall", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    func upgrade(_ name: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["upgrade", name])
    }

    func upgradeAll() -> AsyncThrowingStream<String, Error> {
        process.stream(["upgrade"])
    }

    // MARK: - Cleanup

    func cleanupDryRun() async throws -> String {
        let output = try await process.run(["cleanup", "-n"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output.stdout
    }

    func cleanup() -> AsyncThrowingStream<String, Error> {
        process.stream(["cleanup"])
    }

    func cleanupAggressive() -> AsyncThrowingStream<String, Error> {
        process.stream(["cleanup", "--prune=all", "-s"])
    }

    // MARK: - Services

    func listServices() async throws -> [[String: Any]] {
        let output = try await process.run(["services", "list", "--json"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        guard let data = output.stdout.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw BrewError.parsingFailure(context: "Invalid services JSON")
        }
        return json
    }

    func startService(_ name: String) async throws {
        let output = try await process.run(["services", "start", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    func stopService(_ name: String) async throws {
        let output = try await process.run(["services", "stop", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    func restartService(_ name: String) async throws {
        let output = try await process.run(["services", "restart", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    // MARK: - Health

    func doctor() async throws -> String {
        let output = try await process.run(["doctor"])
        // brew doctor exits non-zero when issues found — that's expected
        return output.stdout + output.stderr
    }

    func missing() async throws -> String {
        let output = try await process.run(["missing"])
        return output.stdout
    }

    // MARK: - Dependencies

    func deps(_ name: String) async throws -> String {
        let output = try await process.run(["deps", "--tree", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output.stdout
    }

    func depsInstalled() async throws -> String {
        let output = try await process.run(["deps", "--installed"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output.stdout
    }

    func uses(_ name: String) async throws -> [String] {
        let output = try await process.run(["uses", "--installed", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        return output.stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: - Brewfile

    func bundleDump(to path: String) async throws {
        let output = try await process.run(["bundle", "dump", "--file=\(path)", "--force"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    func bundleInstall(from path: String) -> AsyncThrowingStream<String, Error> {
        process.stream(["bundle", "install", "--file=\(path)"])
    }

    func bundleCheck(at path: String) async throws -> String {
        let output = try await process.run(["bundle", "check", "--file=\(path)"])
        return output.stdout + output.stderr
    }

    func bundleCleanup(at path: String) async throws -> String {
        let output = try await process.run(["bundle", "cleanup", "--file=\(path)"])
        return output.stdout
    }

    // MARK: - Pin

    func pin(_ name: String) async throws {
        let output = try await process.run(["pin", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    func unpin(_ name: String) async throws {
        let output = try await process.run(["unpin", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    // MARK: - Raw JSON Data

    /// Returns raw JSON `Data` from `brew list --formula --json=v2`.
    func listFormulaeData() async throws -> Data {
        let output = try await process.run(["list", "--formula", "--json=v2"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        guard let data = output.stdout.data(using: .utf8) else {
            throw BrewError.parsingFailure(context: "Invalid UTF-8 in formulae list output")
        }
        return data
    }

    /// Returns raw JSON `Data` from `brew list --cask --json=v2`.
    func listCasksData() async throws -> Data {
        let output = try await process.run(["list", "--cask", "--json=v2"])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        guard let data = output.stdout.data(using: .utf8) else {
            throw BrewError.parsingFailure(context: "Invalid UTF-8 in cask list output")
        }
        return data
    }

    /// Returns raw JSON `Data` from `brew info --json=v2 <name>`.
    func formulaInfoData(_ name: String) async throws -> Data {
        let output = try await process.run(["info", "--json=v2", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        guard let data = output.stdout.data(using: .utf8) else {
            throw BrewError.parsingFailure(context: "Invalid UTF-8 in formula info output")
        }
        return data
    }

    /// Returns raw JSON `Data` from `brew info --cask --json=v2 <name>`.
    func caskInfoData(_ name: String) async throws -> Data {
        let output = try await process.run(["info", "--cask", "--json=v2", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
        guard let data = output.stdout.data(using: .utf8) else {
            throw BrewError.parsingFailure(context: "Invalid UTF-8 in cask info output")
        }
        return data
    }

    // MARK: - Private

    private func parseJSONv2<T>(_ string: String, key: String) throws -> T {
        guard let data = string.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json[key] as? T else {
            throw BrewError.parsingFailure(context: "Missing key '\(key)' in brew JSON output")
        }
        return result
    }
}
