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

    // MARK: Initializer

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

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        self.lastExported = try container.decodeIfPresent(Date.self, forKey: .lastExported)
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(lastExported, forKey: .lastExported)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, lastExported
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
                path: "\(NSHomeDirectory())/Brewfile-Personal",
                lastExported: nil
            ),
        ]
    }
}
