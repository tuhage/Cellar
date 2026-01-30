import Foundation

// MARK: - BrewfileProfile

/// Represents a named Brewfile export profile.
///
/// Each profile stores a name (e.g. "Work Setup") and the file-system
/// path where its Brewfile lives. Profiles are persisted via
/// `PersistenceService` and used by `BrewfileStore` to export / import
/// the current Homebrew state.
public struct BrewfileProfile: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    public let id: UUID
    public var name: String
    public var path: String
    public var lastExported: Date?

    // MARK: Init

    public init(
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

    public static var preview: BrewfileProfile {
        BrewfileProfile(
            name: "Work Setup",
            path: "\(NSHomeDirectory())/Brewfile-Work",
            lastExported: Date(timeIntervalSince1970: 1_768_746_915)
        )
    }

    public static var previewList: [BrewfileProfile] {
        [
            BrewfileProfile(
                name: "Work Setup",
                path: "\(NSHomeDirectory())/Brewfile-Work",
                lastExported: Date(timeIntervalSince1970: 1_768_746_915)
            ),
            BrewfileProfile(
                name: "Personal",
                path: "\(NSHomeDirectory())/Brewfile-Personal"
            ),
        ]
    }
}
