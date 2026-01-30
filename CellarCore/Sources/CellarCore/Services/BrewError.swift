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
}
