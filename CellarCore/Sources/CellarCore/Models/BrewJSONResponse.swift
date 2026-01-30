import Foundation

/// Wrapper for the top-level JSON structure returned by `brew --json=v2` commands.
///
/// Brew v2 JSON always wraps results in `{ "formulae": [...], "casks": [...] }`.
/// Some endpoints (e.g. `brew list --formula`) omit casks, so `casks` is optional.
public struct BrewJSONResponse: Codable, Sendable {
    public let formulae: [Formula]
    public let casks: [Cask]?

    public init(formulae: [Formula], casks: [Cask]? = nil) {
        self.formulae = formulae
        self.casks = casks
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.formulae = try container.decodeIfPresent([Formula].self, forKey: .formulae) ?? []
        self.casks = try container.decodeIfPresent([Cask].self, forKey: .casks)
    }

    private enum CodingKeys: String, CodingKey {
        case formulae, casks
    }
}
