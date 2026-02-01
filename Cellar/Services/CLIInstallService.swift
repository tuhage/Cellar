import Foundation

nonisolated final class CLIInstallService: Sendable {

    enum CLIStatus: Sendable {
        case notBundled
        case notInstalled
        case installed(path: String)
        case conflict(path: String)
    }

    enum InstallError: LocalizedError {
        case notBundled
        case directoryCreationFailed(String)
        case symlinkFailed(String)
        case removeFailed(String)

        var errorDescription: String? {
            switch self {
            case .notBundled:
                "CLI binary not found in app bundle"
            case .directoryCreationFailed(let reason):
                "Failed to create /usr/local/bin: \(reason)"
            case .symlinkFailed(let reason):
                "Failed to create symlink: \(reason)"
            case .removeFailed(let reason):
                "Failed to remove existing file: \(reason)"
            }
        }
    }

    static let installPath = "/usr/local/bin/cellar"

    var bundledBinaryPath: String? {
        Bundle.main.path(forResource: "cellar", ofType: nil)
    }

    func status() -> CLIStatus {
        guard bundledBinaryPath != nil else { return .notBundled }

        let fileManager = FileManager.default
        let installPath = Self.installPath

        guard fileManager.fileExists(atPath: installPath) else {
            return .notInstalled
        }

        // Check if it's a symlink pointing to our bundled binary
        if let destination = try? fileManager.destinationOfSymbolicLink(atPath: installPath) {
            if destination == bundledBinaryPath {
                return .installed(path: installPath)
            }
            return .conflict(path: destination)
        }

        // Exists but is not a symlink — conflict
        return .conflict(path: installPath)
    }

    func install() throws {
        guard let binaryPath = bundledBinaryPath else {
            throw InstallError.notBundled
        }

        let fileManager = FileManager.default
        let installPath = Self.installPath
        let directory = (installPath as NSString).deletingLastPathComponent

        // Create /usr/local/bin if it doesn't exist
        if !fileManager.fileExists(atPath: directory) {
            do {
                try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
            } catch {
                throw InstallError.directoryCreationFailed(error.localizedDescription)
            }
        }

        // Remove existing file/symlink if present
        if fileManager.fileExists(atPath: installPath) {
            do {
                try fileManager.removeItem(atPath: installPath)
            } catch {
                throw InstallError.removeFailed(error.localizedDescription)
            }
        }

        do {
            try fileManager.createSymbolicLink(atPath: installPath, withDestinationPath: binaryPath)
        } catch {
            throw InstallError.symlinkFailed(error.localizedDescription)
        }
    }

    func uninstall() throws {
        let fileManager = FileManager.default
        let installPath = Self.installPath

        guard fileManager.fileExists(atPath: installPath) else { return }

        do {
            try fileManager.removeItem(atPath: installPath)
        } catch {
            throw InstallError.removeFailed(error.localizedDescription)
        }
    }
}
