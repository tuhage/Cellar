import Foundation
import os
import CellarCore

// MARK: - UpdateError

enum UpdateError: LocalizedError {
    case networkFailure(underlying: Error)
    case decodingFailure
    case invalidResponse(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .networkFailure: "Could not reach GitHub."
        case .decodingFailure: "GitHub returned an unexpected response."
        case .invalidResponse(let code): "GitHub returned HTTP \(code)."
        }
    }
}

// MARK: - UpdateService

/// Queries the GitHub Releases API for the latest published release.
/// `nonisolated` so it can run off the main actor.
nonisolated final class UpdateService: Sendable {

    private let releasesURL: URL
    private let session: URLSession

    init(
        owner: String = "tuhage",
        repository: String = "Cellar",
        session: URLSession = .shared
    ) {
        self.releasesURL = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
        self.session = session
    }

    func fetchLatestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Cellar/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Log.app.error("Update check network failure: \(error.localizedDescription, privacy: .public)")
            throw UpdateError.networkFailure(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            Log.app.error("Update check returned HTTP \(http.statusCode, privacy: .public)")
            throw UpdateError.invalidResponse(statusCode: http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(ReleaseInfo.self, from: data)
        } catch {
            Log.app.error("Failed to decode GitHub release: \(error.localizedDescription, privacy: .public)")
            throw UpdateError.decodingFailure
        }
    }

    /// Returns `true` if `latest` is strictly greater than `current` using
    /// semantic-version comparison ("1.10.0" > "1.2.0" — not string compare).
    static func isUpdateAvailable(current: String, latest: String) -> Bool {
        SemanticVersion(latest) > SemanticVersion(current)
    }

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
    }
}
