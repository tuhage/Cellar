import Foundation

public enum BrewError: LocalizedError, Sendable {
    case processFailure(exitCode: Int32, stderr: String)
    case parsingFailure(context: String)
    case brewNotFound
    case commandTimeout
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .processFailure(let exitCode, let stderr):
            "Brew command failed (exit \(exitCode)): \(stderr)"
        case .parsingFailure(let context):
            "Failed to parse brew output: \(context)"
        case .brewNotFound:
            "Homebrew not found. Please install Homebrew first."
        case .commandTimeout:
            "Brew command timed out."
        case .cancelled:
            "Operation was cancelled."
        }
    }

    /// One line for the UI: brew's last `Error:` line rather than the whole
    /// stderr dump, which belongs in the log.
    public var summary: String {
        guard case .processFailure(let exitCode, let stderr) = self else {
            return errorDescription ?? "Unknown error"
        }
        let lines = stderr
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let errorLine = lines.last(where: { $0.hasPrefix("Error:") }) {
            return errorLine.dropFirst("Error:".count).trimmingCharacters(in: .whitespaces)
        }
        return lines.last ?? "Brew command failed (exit \(exitCode))."
    }
}

extension Error {
    /// A one-line description suitable for the UI.
    public var briefDescription: String {
        (self as? BrewError)?.summary ?? localizedDescription
    }
}
