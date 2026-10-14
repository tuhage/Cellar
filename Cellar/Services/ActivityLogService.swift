import Foundation
import CellarCore
import os

/// Mirrors activity logs to `~/Library/Logs/Cellar`, one file per operation,
/// so what happened can still be read after Cellar quits or the activity
/// panel is cleared. The files open in Console.app.
@MainActor
final class ActivityLogService {
    static let shared = ActivityLogService()

    let directory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/Cellar", directoryHint: .isDirectory)

    private static let retainedFileCount = 50
    private static let isRunningForPreviews =
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    private var handles: [UUID: FileHandle] = [:]

    private static let fileNameFormatter = makeFormatter("yyyy-MM-dd HH.mm.ss")
    private static let timeFormatter = makeFormatter("HH:mm:ss")

    private init() {}

    // MARK: Writing

    /// Creates the operation's log file and returns its location.
    func begin(_ operation: BrewOperation) -> URL? {
        guard !Self.isRunningForPreviews else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            pruneOldLogs()
            let url = directory.appending(path: fileName(for: operation))
            guard FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil) else {
                return nil
            }
            handles[operation.id] = try FileHandle(forWritingTo: url)
            write(operation.id, "\(operation.kind.displayTitle) — started \(operation.startedAt.formatted(date: .complete, time: .standard))")
            return url
        } catch {
            Log.activity.error("Couldn't create activity log: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Appends a timestamped line. Operations without a log file are ignored.
    func append(_ id: UUID, _ line: String) {
        write(id, "[\(Self.timeFormatter.string(from: .now))] \(line)")
    }

    /// Records the outcome and closes the file.
    func end(_ id: UUID, status: BrewOperation.Status) {
        let outcome = switch status {
        case .running: "Still running"
        case .succeeded: "Completed"
        case .failed(let reason): "Failed — \(reason)"
        case .cancelled: "Cancelled"
        }
        append(id, "== \(outcome)")
        try? handles[id]?.close()
        handles[id] = nil
    }

    // MARK: Private

    private func write(_ id: UUID, _ text: String) {
        guard let handle = handles[id] else { return }
        do {
            try handle.write(contentsOf: Data((text + "\n").utf8))
        } catch {
            Log.activity.error("Couldn't write activity log: \(error.localizedDescription, privacy: .public)")
            try? handle.close()
            handles[id] = nil
        }
    }

    /// "2026-10-14 15.42.10 Upgrading 8 packages.log" — sorts by date in Finder.
    private func fileName(for operation: BrewOperation) -> String {
        let title = operation.kind.displayTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(Self.fileNameFormatter.string(from: operation.startedAt)) \(title).log"
    }

    private func pruneOldLogs() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        let logs = files
            .filter { $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for url in logs.dropFirst(Self.retainedFileCount - 1) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}
