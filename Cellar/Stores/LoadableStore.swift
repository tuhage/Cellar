import Foundation

/// A protocol that formalises the loading/error state shared by all Store objects.
///
/// Provides:
/// - `isLoading` / `errorMessage` requirements
/// - `clearError()` default implementation
/// - `withLoading(_:)` async helper that manages the loading flag and surfaces errors
///
/// All stores conforming to this protocol must be `@MainActor` classes.
@MainActor
protocol LoadableStore: AnyObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
}

extension LoadableStore {

    func clearError() {
        errorMessage = nil
    }

    /// Runs `block`, managing `isLoading` and surfacing any thrown error into `errorMessage`.
    /// Returns `nil` if `block` throws; returns the value otherwise.
    func withLoading<T: Sendable>(
        _ block: @MainActor () async throws -> T
    ) async -> T? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await block()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
