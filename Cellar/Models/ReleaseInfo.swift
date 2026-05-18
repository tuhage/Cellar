import Foundation

/// GitHub Releases API response (minimum fields).
struct ReleaseInfo: Decodable, Sendable, Equatable {
    let tagName: String
    let htmlUrl: URL
    let body: String
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
        case publishedAt = "published_at"
    }

    /// Strips the "v" prefix from `tagName`. E.g. "v1.2.0" → "1.2.0".
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}
