import Foundation

extension BrewService {

    public func listTapsData() async throws -> Data {
        try await runJSON(["tap-info", "--json", "--installed"])
    }

    /// Taps `name`, cloning `remote` instead of GitHub's
    /// `user/homebrew-repo` when one is given.
    public func addTap(_ name: String, remote: String? = nil) -> AsyncThrowingStream<String, Error> {
        process.stream(["tap", name] + [remote].compactMap { $0 }, includingStandardError: true)
    }

    /// brew refuses to untap while installed packages come from the tap;
    /// `force` untaps anyway and leaves those packages installed.
    public func removeTap(_ name: String, force: Bool = false) async throws {
        try await runChecked(["untap"] + (force ? ["--force"] : []) + [name])
    }
}
