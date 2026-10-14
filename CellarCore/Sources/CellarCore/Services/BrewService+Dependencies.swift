import Foundation

extension BrewService {

    public func deps(_ name: String) async throws -> String {
        let output = try await runChecked(["deps", "--tree", name])
        return output.stdout
    }

    /// Every installed package with all of its runtime dependencies, direct
    /// and indirect, as one `package: dep dep…` line each.
    public func depsInstalled() async throws -> String {
        let output = try await runChecked(["deps", "--installed"])
        return output.stdout
    }

    public func uses(_ name: String) async throws -> [String] {
        let output = try await runChecked(["uses", "--installed", name])
        return parseLines(output.stdout)
    }
}
