import Foundation

extension Array<String> {
    /// "a, b, c and 4 more" — names for a sentence, capped so a
    /// confirmation stays readable.
    func briefList(limit: Int = 5) -> String {
        guard count > limit else { return formatted(.list(type: .and)) }
        return (prefix(limit) + ["\(count - limit) more"]).formatted(.list(type: .and))
    }
}
