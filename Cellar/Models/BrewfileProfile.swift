import Foundation

// MARK: - BrewfileProfile

/// Represents a named Brewfile export profile.
///
/// Each profile stores a name (e.g. "Work Setup") and the file-system
/// path where its Brewfile lives. Profiles are persisted via
/// `PersistenceService` and used by `BrewfileStore` to export / import
/// the current Homebrew state.
struct BrewfileProfile: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    let id: UUID
    var name: String
    var path: String
    var lastExported: Date?

    // MARK: Initializer

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        lastExported: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.lastExported = lastExported
    }

    // MARK: Preview

    static var preview: BrewfileProfile {
        BrewfileProfile(
            name: "Work Setup",
            path: "\(NSHomeDirectory())/Brewfile-Work",
            lastExported: Date(timeIntervalSince1970: 1_768_746_915)
        )
    }

    static var previewList: [BrewfileProfile] {
        [
            BrewfileProfile(
                name: "Work Setup",
                path: "\(NSHomeDirectory())/Brewfile-Work",
                lastExported: Date(timeIntervalSince1970: 1_768_746_915)
            ),
            BrewfileProfile(
                name: "Personal",
                path: "\(NSHomeDirectory())/Brewfile-Personal",
                lastExported: nil
            ),
        ]
    }
}
