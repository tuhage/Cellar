import Foundation

/// Wrapper for the top-level JSON structure returned by `brew --json=v2` commands.
///
/// Brew v2 JSON always wraps results in `{ "formulae": [...], "casks": [...] }`.
/// Some endpoints (e.g. `brew list --formula`) omit casks, so `casks` is optional.
struct BrewJSONResponse: Codable, Sendable {
    let formulae: [Formula]
    let casks: [Cask]?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.formulae = try container.decodeIfPresent([Formula].self, forKey: .formulae) ?? []
        self.casks = try container.decodeIfPresent([Cask].self, forKey: .casks)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formulae, forKey: .formulae)
        try container.encodeIfPresent(casks, forKey: .casks)
    }

    private enum CodingKeys: String, CodingKey {
        case formulae
        case casks
    }
}
