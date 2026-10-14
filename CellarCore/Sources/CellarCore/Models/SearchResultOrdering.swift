import Foundation

/// Combines `brew search` names with the `brew info` details fetched for
/// some of them.
enum SearchResultOrdering {

    /// One result per name, in brew's order: the described package when
    /// `details` has one matching any of its `keys`, a stub otherwise.
    static func ordered<Package>(
        _ names: [String],
        details: [Package],
        keys: (Package) -> [String],
        stub: (String) -> Package
    ) -> [Package] {
        var byKey: [String: Package] = [:]
        for package in details {
            for key in keys(package) {
                byKey[key] = package
            }
        }
        return names.map { byKey[$0] ?? stub($0) }
    }
}
